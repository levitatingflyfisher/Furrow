import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/features/habits/domain/franklin_virtues.dart';

void main() {
  group('virtueOfWeek', () {
    test('rotates through the 13 virtues weekly from the anchor Monday', () {
      final anchor = DateTime(2025, 12, 29); // Monday of ISO week 1 of 2026
      expect(virtueOfWeek(anchor, anchor), same(kFranklinVirtues[0]));
      expect(virtueOfWeek(anchor, DateTime(2026, 1, 4)), // Sunday, same week
          same(kFranklinVirtues[0]));
      expect(virtueOfWeek(anchor, DateTime(2026, 1, 5)), // next Monday
          same(kFranklinVirtues[1]));
    });

    test('week index is calendar-stable across a spring-forward', () {
      final anchor = DateTime(2025, 12, 29); // Monday of ISO week 1 of 2026
      // Monday 2026-03-09 is exactly 70 calendar days past the anchor —
      // week 10 — in every timezone, even though only 70*24-1 hours have
      // elapsed in a US DST zone (the old difference().inDays form read
      // 69 days and kept the previous week's virtue a day too long).
      expect(virtueOfWeek(anchor, DateTime(2026, 3, 9)),
          same(kFranklinVirtues[10]));
      // The whole week shares that virtue.
      expect(virtueOfWeek(anchor, DateTime(2026, 3, 15)),
          same(kFranklinVirtues[10]));
    });
  });
}
