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

/// How far [day] has progressed toward the habit's target, in `[0, 1]`. This
/// drives the cell's partial fill, so a single tap (a +1 count, a logged
/// minute) is acknowledged immediately instead of staying blank until the
/// whole target lands.
double dayProgress(Habit h, List<HabitMark> marks, DateTime day) {
  final key = day.toDateDay();
  final value = dayValue(h, marks.where((m) => m.dateDay == key));
  if (h.targetValue <= 0) return value > 0 ? 1.0 : 0.0;
  return (value / h.targetValue).clamp(0.0, 1.0);
}

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

// ── Streaks respect the schedule ──────────────────────────────────────────
// A scheduled day left undone breaks a run; a day the habit is not scheduled
// is neutral (not a miss); a completion on an unscheduled day still counts.
// So a Mon/Wed/Fri habit kept perfectly runs 3 a week, not 1 forever, and a
// daily habit is exactly the old calendar streak. For the same marks this is
// never shorter than the old calendar-day count, so the change revokes
// nothing (schedule_streak_test checks that property). weeklyCount habits
// are "any day" (see isScheduledOn), so they still count calendar days.
//
// Walk the calendar, not elapsed time: DateTime(y, m, d - 1) always lands on
// the previous calendar day, where subtract(Duration(days: 1)) is 24 elapsed
// hours and lands on 23:00 two days back across a DST spring-forward.

/// The current run ending today (or yesterday while today is still pending).
int currentStreak(Habit h, List<HabitMark> marks, DateTime today) {
  final done = completedDayKeys(h, marks);
  if (done.isEmpty) return 0;
  // The walk stops before the earliest completion: nothing earlier can add
  // to the run, and a schedule with no days would otherwise never break.
  final earliest = (done.toList()..sort()).first;
  var cursor = DateTime(today.year, today.month, today.day);
  // Today not yet done? It is pending, not missed.
  if (!done.contains(cursor.toDateDay())) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  var streak = 0;
  while (cursor.toDateDay().compareTo(earliest) >= 0) {
    if (done.contains(cursor.toDateDay())) {
      streak++;
    } else if (isScheduledOn(h, cursor)) {
      break;
    }
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

/// The longest run ever, by the same rule as [currentStreak].
int bestStreak(Habit h, List<HabitMark> marks) {
  final keys = completedDayKeys(h, marks).toList()..sort();
  if (keys.isEmpty) return 0;
  final done = keys.toSet();
  final last = DateTime.parse(keys.last);
  var cursor = DateTime.parse(keys.first);
  var best = 0, run = 0;
  while (!cursor.isAfter(last)) {
    if (done.contains(cursor.toDateDay())) {
      run++;
      if (run > best) best = run;
    } else if (isScheduledOn(h, cursor)) {
      run = 0;
    }
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return best;
}

/// Total number of completed days for a habit (Stats consistency, no %).
int completedDayCount(Habit h, List<HabitMark> marks) =>
    completedDayKeys(h, marks).length;
