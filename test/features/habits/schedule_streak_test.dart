import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';

/// Streaks respect the schedule (fleet ruling): a day the habit is not
/// scheduled is not a miss. The rule: a scheduled day left undone breaks the
/// run; an unscheduled day is neutral; a completion on an unscheduled day
/// still counts. (furrow:gamers-brain-01: a Mon/Wed/Fri habit kept
/// perfectly read "Running 1 / Best 1" forever, and three awards could never
/// light for it.)
const _monWedFri = 1 | 4 | 16; // bits 0, 2, 4

Habit _habit({int mask = kDailyMask}) => Habit(
      id: 'h',
      name: 'Gym',
      cadence: Cadence.binary.name,
      scheduleType: mask == kDailyMask
          ? ScheduleType.daily.name
          : ScheduleType.specificDays.name,
      targetValue: 1,
      weekdayMask: mask,
      colorValue: 0xFFB07A2E,
      archived: false,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
    );

HabitMark _mark(DateTime d) => HabitMark(
      id: 'h-${d.toDateDay()}',
      habitId: 'h',
      dateDay: d.toDateDay(),
      value: 1,
      completed: true,
      createdAt: 0,
      updatedAt: 0,
    );

/// The old calendar-day streaks, as the reference the new ones must never
/// fall below ("nothing earned is revoked" for this change).
int _calendarCurrent(Set<String> done, DateTime today) {
  var c = DateTime(today.year, today.month, today.day);
  if (!done.contains(c.toDateDay())) c = DateTime(c.year, c.month, c.day - 1);
  var n = 0;
  while (done.contains(c.toDateDay())) {
    n++;
    c = DateTime(c.year, c.month, c.day - 1);
  }
  return n;
}

int _calendarBest(Set<String> done) {
  final keys = done.toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final k in keys) {
    final d = DateTime.parse(k);
    run = (prev != null && daysBetweenDates(prev, d) == 1) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

void main() {
  final friday = DateTime(2026, 7, 17); // a Friday

  List<HabitMark> monWedFriFor(int weeks, {required DateTime through}) => [
        for (var i = 0; i < weeks * 7; i++)
          if (_monWedFri.includesWeekday(
              DateTime(through.year, through.month, through.day - i).weekday))
            _mark(DateTime(through.year, through.month, through.day - i)),
      ];

  test('a Mon/Wed/Fri habit kept for three weeks runs 9, not 1', () {
    final marks = monWedFriFor(3, through: friday);
    expect(marks, hasLength(9));
    final h = _habit(mask: _monWedFri);
    expect(currentStreak(h, marks, friday), 9);
    expect(bestStreak(h, marks), 9);
  });

  test('the run survives the unscheduled weekend while today is pending', () {
    final marks = monWedFriFor(2, through: friday);
    final sunday = DateTime(2026, 7, 19);
    expect(currentStreak(_habit(mask: _monWedFri), marks, sunday), 6);
  });

  test('a scheduled day left undone breaks the run', () {
    final marks = monWedFriFor(2, through: friday)
      ..removeWhere((m) => m.dateDay == '2026-07-15'); // this Wednesday
    final h = _habit(mask: _monWedFri);
    expect(currentStreak(h, marks, friday), 1);
    expect(bestStreak(h, marks), 4);
  });

  test('a completion on an unscheduled day counts', () {
    final marks = [
      ...monWedFriFor(1, through: friday),
      _mark(DateTime(2026, 7, 18)), // Saturday, extra
    ];
    expect(currentStreak(_habit(mask: _monWedFri), marks,
        DateTime(2026, 7, 18)), 4);
  });

  test('a daily habit is unchanged', () {
    final marks = [
      for (var i = 0; i < 5; i++) _mark(DateTime(2026, 7, 17 - i)),
    ];
    expect(currentStreak(_habit(), marks, friday), 5);
    expect(bestStreak(_habit(), marks), 5);
  });

  test('a schedule with no days terminates and counts only completions', () {
    final h = _habit(mask: 0);
    final marks = [_mark(DateTime(2026, 7, 10)), _mark(DateTime(2026, 7, 17))];
    expect(currentStreak(h, marks, friday), 2);
    expect(bestStreak(h, marks), 2);
    expect(currentStreak(h, const [], friday), 0);
  });

  test('never shorter than the old calendar streak on the same marks', () {
    final rng = Random(7);
    for (var trial = 0; trial < 300; trial++) {
      final mask = rng.nextInt(128);
      final marks = <HabitMark>[];
      for (var i = 0; i < 40; i++) {
        if (rng.nextDouble() < 0.6) {
          marks.add(_mark(DateTime(2026, 7, 17 - i)));
        }
      }
      final done = marks.map((m) => m.dateDay).toSet();
      final h = _habit(mask: mask == 0 ? kDailyMask : mask);
      expect(currentStreak(h, marks, friday),
          greaterThanOrEqualTo(_calendarCurrent(done, friday)),
          reason: 'mask $mask trial $trial');
      expect(bestStreak(h, marks), greaterThanOrEqualTo(_calendarBest(done)),
          reason: 'mask $mask trial $trial');
    }
  });
}
