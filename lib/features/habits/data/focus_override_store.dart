import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';

/// Per-week focus-virtue overrides, keyed by the week's Monday in the
/// userPrefs KV table (`focus_virtue_2026-07-27`). Written only from the
/// Today surface — never before onboarding, whose "prefs table empty"
/// sentinel must stay meaningful.
class FocusOverrideStore {
  FocusOverrideStore(this._db);

  final AppDatabase _db;

  String _key(DateTime weekMonday) =>
      'focus_virtue_${weekMonday.startOfWeek.toDateDay()}';

  Future<String?> overrideFor(DateTime weekMonday) async {
    final row = await (_db.select(_db.userPrefs)
          ..where((p) => p.key.equals(_key(weekMonday))))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setOverride(DateTime weekMonday, String virtueKey) =>
      _db.into(_db.userPrefs).insertOnConflictUpdate(
          UserPrefsCompanion.insert(key: _key(weekMonday), value: virtueKey));

  Future<void> clearOverride(DateTime weekMonday) async {
    await (_db.delete(_db.userPrefs)
          ..where((p) => p.key.equals(_key(weekMonday))))
        .go();
  }
}
