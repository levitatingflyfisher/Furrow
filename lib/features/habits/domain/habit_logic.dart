// lib/features/habits/domain/habit_logic.dart
//
// Pure functions over Habit + its marks. No DB, no widgets — easy to unit test.
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';

/// Whether a habit is expected on [day] given its schedule. weeklyCount is
/// treated as "any day" for v1 (week-grained UI deferred).
bool isScheduledOn(Habit h, DateTime day) {
  switch (ScheduleType.fromName(h.scheduleType)) {
    case ScheduleType.daily:
    case ScheduleType.weeklyCount:
      return true;
    case ScheduleType.specificDays:
      return h.weekdayMask.includesWeekday(day.weekday);
  }
}

/// The day's accumulated value for a habit from that day's marks. Binary/count =
/// the single row's value; duration = SUM of session seconds.
int dayValue(Habit h, Iterable<HabitMark> dayMarks) {
  final cadence = Cadence.fromName(h.cadence);
  final mine = dayMarks.where((m) => m.habitId == h.id);
  if (cadence == Cadence.duration) {
    return mine.fold(0, (sum, m) => sum + (m.durationSecs ?? 0));
  }
  return mine.isEmpty ? 0 : mine.first.value;
}

/// Whether [value] meets the habit's target (binary target is 1).
bool isMet(Habit h, int value) => value >= h.targetValue;

/// The set of `yyyy-MM-dd` day-keys on which the habit was completed, derived
/// from all its marks (duration is summed per day against the target).
Set<String> completedDayKeys(Habit h, List<HabitMark> marks) {
  final cadence = Cadence.fromName(h.cadence);
  if (cadence == Cadence.duration) {
    final perDay = <String, int>{};
    for (final m in marks) {
      perDay[m.dateDay] = (perDay[m.dateDay] ?? 0) + (m.durationSecs ?? 0);
    }
    return perDay.entries
        .where((e) => e.value >= h.targetValue)
        .map((e) => e.key)
        .toSet();
  }
  return marks.where((m) => m.completed).map((m) => m.dateDay).toSet();
}

/// Consecutive completed calendar days ending today (or yesterday if today is
/// still pending). Schedule-naive in v1; resets silently on any gap.
int currentStreak(Habit h, List<HabitMark> marks, DateTime today) {
  final done = completedDayKeys(h, marks);
  if (done.isEmpty) return 0;
  var cursor = DateTime(today.year, today.month, today.day);
  // Today not yet done? The streak may still be alive up to yesterday.
  if (!done.contains(cursor.toDateDay())) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (done.contains(cursor.toDateDay())) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Longest run of consecutive completed calendar days ever.
int bestStreak(Habit h, List<HabitMark> marks) {
  final keys = completedDayKeys(h, marks).toList()..sort();
  if (keys.isEmpty) return 0;
  var best = 1, run = 1;
  DateTime parse(String k) => DateTime.parse(k);
  for (var i = 1; i < keys.length; i++) {
    final prev = parse(keys[i - 1]);
    final cur = parse(keys[i]);
    if (cur.difference(prev).inDays == 1) {
      run++;
    } else {
      run = 1;
    }
    if (run > best) best = run;
  }
  return best;
}

/// Total number of completed days for a habit (Stats consistency, no %).
int completedDayCount(Habit h, List<HabitMark> marks) =>
    completedDayKeys(h, marks).length;
