import 'package:furrow/features/settings/domain/user_prefs.dart';
import 'package:openhearth_design/openhearth_design.dart';

abstract interface class SettingsRepository {
  Future<UserPrefs> getUserPrefs();
  Stream<UserPrefs> watchUserPrefs();
  Future<void> setThemeMode(OhThemeModePreference mode);
  Future<void> setTimeFormat(TimeFormat format);
  /// Records that onboarding is done. The router sends a device with no
  /// preference rows to onboarding, so this is what lets a new user out.
  Future<void> markOnboarded();
}
