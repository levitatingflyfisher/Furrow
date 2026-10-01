import 'package:furrow/core/storage/app_database.dart' hide UserPrefs;
import 'package:furrow/features/settings/domain/settings_repository.dart';
import 'package:furrow/features/settings/domain/user_prefs.dart';
import 'package:openhearth_design/openhearth_design.dart';

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._db);
  final AppDatabase _db;

  // The theme is stored as OhThemeModePreference.storageValue under
  // 'theme_mode'. Older builds wrote a two-way 'theme' = light/dark; it is
  // still read (see _themeFrom) because a restored old backup brings it back.
  static const _kThemeMode = 'theme_mode';
  static const _kLegacyTheme = 'theme';
  static const _kTimeFormat = 'time_format';
  // Furrow's week is Monday-first everywhere (the grid, the virtue rotation,
  // Clean Week). An older build wrote a 'week_start' row that nothing read;
  // it is left alone and ignored.
  static const _kOnboarded = 'onboarded';

  Future<void> _set(String key, String value) => _db
      .into(_db.userPrefs)
      .insertOnConflictUpdate(UserPrefsCompanion.insert(key: key, value: value));

  @override
  Future<UserPrefs> getUserPrefs() async {
    final rows = await _db.select(_db.userPrefs).get();
    final map = {for (final r in rows) r.key: r.value};
    return _fromMap(map);
  }

  @override
  Stream<UserPrefs> watchUserPrefs() =>
      _db.select(_db.userPrefs).watch().map((rows) {
        final map = {for (final r in rows) r.key: r.value};
        return _fromMap(map);
      });

  @override
  Future<void> setThemeMode(OhThemeModePreference mode) =>
      _set(_kThemeMode, mode.storageValue);

  @override
  Future<void> setTimeFormat(TimeFormat format) =>
      _set(_kTimeFormat, format == TimeFormat.h12 ? '12h' : '24h');

  @override
  Future<void> markOnboarded() => _set(_kOnboarded, 'true');

  UserPrefs _fromMap(Map<String, String> map) => UserPrefs(
    themeMode: _themeFrom(map),
    timeFormat: map[_kTimeFormat] == '24h' ? TimeFormat.h24 : TimeFormat.h12,
  );

  /// A stored choice wins. Otherwise the legacy two-way value: 'dark' was a
  /// deliberate choice and stays dark; 'light' was also what an untouched
  /// install showed, so it (and no value at all) follows the phone.
  OhThemeModePreference _themeFrom(Map<String, String> map) {
    final chosen = map[_kThemeMode];
    if (chosen != null) return OhThemeModePreference.fromStorage(chosen);
    return map[_kLegacyTheme] == 'dark'
        ? OhThemeModePreference.dark
        : OhThemeModePreference.system;
  }
}
