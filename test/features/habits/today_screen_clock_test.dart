import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/presentation/today_screen.dart';

/// TodayScreen must derive "today" from package:clock, not DateTime.now(),
/// so tests (goldens especially) can pin the date. Un-pinned, the week
/// strip's highlighted column moves every real-world day and the golden
/// suite rots on schedule.
void main() {
  testWidgets('week strip highlights the clock-pinned day, not the wall clock',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    await repo.createHabit(name: 'Walk', cadence: Cadence.binary);

    // Monday 2026-07-13, noon (mid-day dodges DST edges).
    final pinned = DateTime(2026, 7, 13, 12);
    await withClock(Clock.fixed(pinned), () async {
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: TodayScreen())),
      ));
      await tester.pumpAndSettle();

      FontWeight? weightOf(String letter) =>
          tester.widget<Text>(find.text(letter).first).style?.fontWeight;

      // Monday's column is today under the pinned clock...
      expect(weightOf('M'), FontWeight.w800,
          reason: 'pinned Monday must be the emphasized column');
      // ...and the unique letters of every other weekday are not.
      expect(weightOf('W'), isNot(FontWeight.w800));
      expect(weightOf('F'), isNot(FontWeight.w800),
          reason: 'the real wall-clock day must NOT leak into the strip');
    });

    // Drift schedules a zero-duration Timer when its query streams lose
    // their last listener; unmount + elapse it inside the test body (same
    // teardown idiom as visual_golden_helper.dart).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
