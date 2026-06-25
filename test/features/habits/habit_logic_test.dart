import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';

Habit _habit({
  String id = 'h',
  Cadence cadence = Cadence.binary,
  int target = 1,
  ScheduleType schedule = ScheduleType.daily,
  int weekdayMask = kDailyMask,
}) =>
    Habit(
      id: id,
      name: 'Test',
      cadence: cadence.name,
      scheduleType: schedule.name,
      targetValue: target,
      weekdayMask: weekdayMask,
      colorValue: 0xFFB07A2E,
      archived: false,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
    );

HabitMark _mark({
  required String day,
  int value = 1,
  bool completed = true,
  int? durationSecs,
  String habitId = 'h',
}) =>
    HabitMark(
      id: '$habitId-$day-${durationSecs ?? value}',
      habitId: habitId,
      dateDay: day,
      value: value,
      completed: completed,
      durationSecs: durationSecs,
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  final today = DateTime(2026, 6, 25); // a Thursday
  String day(int ago) => today.subtract(Duration(days: ago)).toDateDay();

  group('currentStreak (binary, schedule-naive)', () {
    test('counts consecutive completed days ending today', () {
      final marks = [_mark(day: day(0)), _mark(day: day(1)), _mark(day: day(2))];
      expect(currentStreak(_habit(), marks, today), 3);
    });

    test('stays alive up to yesterday when today is still pending', () {
      final marks = [_mark(day: day(1)), _mark(day: day(2))];
      expect(currentStreak(_habit(), marks, today), 2);
    });

    test('resets on a gap', () {
      final marks = [_mark(day: day(0)), _mark(day: day(3)), _mark(day: day(4))];
      expect(currentStreak(_habit(), marks, today), 1);
    });

    test('is zero with no completed marks', () {
      expect(currentStreak(_habit(), const [], today), 0);
      expect(
        currentStreak(_habit(), [_mark(day: day(0), completed: false)], today),
        0,
      );
    });
  });

  group('bestStreak', () {
    test('finds the longest run regardless of recency', () {
      final marks = [
        _mark(day: day(10)), _mark(day: day(9)), _mark(day: day(8)),
        _mark(day: day(7)), // a 4-run
        _mark(day: day(1)), _mark(day: day(0)), // a 2-run
      ];
      expect(bestStreak(_habit(), marks), 4);
    });
  });

  group('duration completion is derived per day from summed seconds', () {
    test('two sessions summing past target complete the day', () {
      final h = _habit(cadence: Cadence.duration, target: 1800); // 30 min
      final marks = [
        _mark(day: day(0), durationSecs: 1000, completed: false),
        _mark(day: day(0), durationSecs: 900, completed: false), // 1900 >= 1800
      ];
      expect(completedDayKeys(h, marks), {day(0)});
      expect(currentStreak(h, marks, today), 1);
    });

    test('a day short of target does not count', () {
      final h = _habit(cadence: Cadence.duration, target: 1800);
      final marks = [_mark(day: day(0), durationSecs: 600, completed: false)];
      expect(completedDayKeys(h, marks), isEmpty);
    });
  });

  group('isScheduledOn', () {
    test('daily is always scheduled', () {
      expect(isScheduledOn(_habit(), today), isTrue);
    });

    test('specificDays respects the weekday mask', () {
      // today is Thursday (weekday 4 -> bit3). Mask with only Monday (bit0).
      final monOnly = _habit(
          schedule: ScheduleType.specificDays, weekdayMask: 1 << 0);
      expect(isScheduledOn(monOnly, today), isFalse);
      final thuOnly = _habit(
          schedule: ScheduleType.specificDays, weekdayMask: 1 << 3);
      expect(isScheduledOn(thuOnly, today), isTrue);
    });
  });
}
