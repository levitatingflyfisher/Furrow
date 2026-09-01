import 'package:openhearth_design/openhearth_design.dart';

enum FlowTimerStyle { arc, gnomon, dualRing }

enum TimeFormat { h12, h24 }

class UserPrefs {
  const UserPrefs({
    this.annualGoalHours = 1000,
    this.monthlyGoalHours,
    this.flowTimerStyle = FlowTimerStyle.gnomon,
    this.autoStopEnabled = false,
    this.autoStopThresholdHours = 2,
    this.themeMode = OhThemeModePreference.defaultValue,
    this.timeFormat = TimeFormat.h12,
  });

  final int annualGoalHours;
  final int? monthlyGoalHours;
  final FlowTimerStyle flowTimerStyle;
  final bool autoStopEnabled;
  final int autoStopThresholdHours;
  /// Light, dark, or follow the phone (the default).
  final OhThemeModePreference themeMode;
  final TimeFormat timeFormat;
}
