import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';

void main() {
  group('DateTimeExt', () {
    test('toDateDay returns YYYY-MM-DD', () {
      final dt = DateTime(2026, 3, 28, 14, 30);
      expect(dt.toDateDay(), '2026-03-28');
    });

    test('toYearMonth returns YYYY-MM', () {
      final dt = DateTime(2026, 3, 28);
      expect(dt.toYearMonth(), '2026-03');
    });

    test('toYear returns YYYY', () {
      final dt = DateTime(2026, 3, 28);
      expect(dt.toYear(), '2026');
    });

    test('dateOnly drops the time component', () {
      expect(DateTime(2026, 3, 28, 14, 30).dateOnly, DateTime(2026, 3, 28));
    });

    test('startOfWeek returns the date-only Monday', () {
      // 2026-03-28 is a Saturday → Monday is 2026-03-23.
      expect(DateTime(2026, 3, 28, 9).startOfWeek, DateTime(2026, 3, 23));
      // A Monday is its own week start.
      expect(DateTime(2026, 3, 23).startOfWeek, DateTime(2026, 3, 23));
    });
  });

  group('daysBetweenDates (DST-safe)', () {
    test('counts whole calendar days ignoring the time component', () {
      expect(daysBetweenDates(DateTime(2026, 3, 2), DateTime(2026, 3, 9)), 7);
      expect(
          daysBetweenDates(
              DateTime(2026, 3, 2, 23, 59), DateTime(2026, 3, 9, 0, 1)),
          7);
    });

    test('timestamps 167h apart spanning 7 calendar days count 7', () {
      // TZ-independent repro of the truncation class: 167h = 6d23h, so a
      // naive b.difference(a).inDays truncates to 6 even though the two
      // timestamps sit on calendar days 7 apart. This is exactly what a
      // DST spring-forward does to midnight cursors.
      final a = DateTime(2026, 3, 1, 23, 30);
      final b = a.add(const Duration(hours: 167)); // 2026-03-08 22:30 ± DST
      expect(b.difference(a).inDays, 6, reason: 'the naive form truncates');
      expect(daysBetweenDates(a, b), 7);
    });

    test('a US spring-forward between the dates does not drop a day', () {
      // 2026-03-08 is the US DST spring-forward. A naive
      // b.difference(a).inDays over these two local midnights truncates 167h
      // to 6 in a DST zone; the calendar-day helper stays 7.
      final a = DateTime(2026, 3, 2); // Monday
      final b = DateTime(2026, 3, 9); // the next Monday, past the transition
      expect(daysBetweenDates(a, b), 7);
    });

    test('is signed: reversing the arguments negates the count', () {
      expect(daysBetweenDates(DateTime(2026, 3, 9), DateTime(2026, 3, 2)), -7);
    });

    test('same calendar day (any times) is zero', () {
      expect(daysBetweenDates(DateTime(2026, 3, 8, 1), DateTime(2026, 3, 8, 23)),
          0);
    });
  });

  group('minutesToLabel', () {
    test('formats morning and afternoon 12-hour times', () {
      expect(minutesToLabel(0), '12:00 AM');
      expect(minutesToLabel(7 * 60), '7:00 AM');
      expect(minutesToLabel(12 * 60), '12:00 PM');
      expect(minutesToLabel(13 * 60 + 5), '1:05 PM');
      expect(minutesToLabel(22 * 60 + 30), '10:30 PM');
    });
  });
}
