import 'package:openhearth_design/openhearth_design.dart';

enum TimeFormat { h12, h24 }

class UserPrefs {
  const UserPrefs({
    this.themeMode = OhThemeModePreference.defaultValue,
    this.timeFormat = TimeFormat.h12,
  });

  /// Light, dark, or follow the phone (the default).
  final OhThemeModePreference themeMode;
  final TimeFormat timeFormat;
}
