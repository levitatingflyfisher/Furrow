/// Domain enums for habits. Stored in the DB as their `.name` string.

/// How a habit is satisfied on a given day.
enum Cadence {
  /// A single daily tick (done / not done).
  binary,

  /// Reach a count target per day via a stepper (e.g. 8 glasses).
  count,

  /// Accumulate time toward a target via the timer (e.g. 30 min reading).
  duration;

  static Cadence fromName(String s) => Cadence.values.firstWhere(
        (c) => c.name == s,
        orElse: () => Cadence.binary,
      );
}

/// When a habit is expected.
enum ScheduleType {
  /// Every day.
  daily,

  /// Specific weekdays, per [Habits.weekdayMask].
  specificDays,

  /// N times within a calendar week (schema-ready; UI deferred to a later release).
  weeklyCount;

  static ScheduleType fromName(String s) => ScheduleType.values.firstWhere(
        (c) => c.name == s,
        orElse: () => ScheduleType.daily,
      );
}

/// The shape of an award's unlock check (hardcoded in AwardService for v1).
enum BadgeKind {
  firstMark,
  chainDays,
  cleanWeek,
  countTarget,
  durationTotal,
  breadth;

  static BadgeKind fromName(String s) => BadgeKind.values.firstWhere(
        (c) => c.name == s,
        orElse: () => BadgeKind.firstMark,
      );
}

/// Bit-mask helpers for [Habits.weekdayMask]: Mon=bit0 .. Sun=bit6.
extension WeekdayMask on int {
  /// [weekday] uses `DateTime.monday`(1) .. `DateTime.sunday`(7).
  bool includesWeekday(int weekday) => (this & (1 << (weekday - 1))) != 0;
}

/// All seven days set.
const int kDailyMask = 127;
