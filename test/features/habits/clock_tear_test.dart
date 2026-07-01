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
import 'package:furrow/features/habits/presentation/garden_screen.dart';
import 'package:furrow/features/habits/presentation/habit_detail_screen.dart';
import 'package:furrow/features/habits/presentation/log_time_sheet.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';

/// TodayScreen already derives "today" from package:clock — the flows it
/// triggers must too, or a session spanning midnight tears: the grid shows
/// one day while the log sheet writes, and the streaks read, another.
/// These tests pin the clock far from the wall-clock date and require every
/// surface to follow the pinned day.
void main() {
  // Monday 2026-07-13, noon (mid-day dodges DST edges).
  final pinned = DateTime(2026, 7, 13, 12);

  late AppDatabase db;
  late HabitsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
  });

  tearDown(() => db.close());

  Future<void> unmountAndDrainDrift(WidgetTester tester) async {
    // Drift schedules a zero-duration Timer when its query streams lose
    // their last listener; unmount + elapse it inside the test body (same
    // teardown idiom as visual_golden_helper.dart).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('LogTimeSheet writes the logged session to the clock-pinned day',
      (tester) async {
    final id = await repo.createHabit(
        name: 'Read', cadence: Cadence.duration, targetValue: 1500);
    final habit = (await repo.getHabit(id))!;

    await withClock(Clock.fixed(pinned), () async {
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: Scaffold(body: LogTimeSheet(habit: habit))),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('quickadd_5')));
      await tester.pumpAndSettle();
    });

    final marks = await repo.allMarksOnce();
    expect(marks, hasLength(1));
    expect(marks.single.dateDay, '2026-07-13',
        reason: 'the session must land on the pinned day, not the '
            'wall-clock day the grid is no longer showing');

    await unmountAndDrainDrift(tester);
  });

  testWidgets('GardenScreen computes the running streak from the pinned day',
      (tester) async {
    final id = await repo.createHabit(name: 'Walk', cadence: Cadence.binary);
    final habit = (await repo.getHabit(id))!;
    // Marked yesterday + pinned-today: a 2-day running streak under the
    // pinned clock, a long-broken one under the real wall clock.
    await repo.setBinary(habit, DateTime(2026, 7, 12).toDateDay(), true);
    await repo.setBinary(habit, pinned.toDateDay(), true);

    await withClock(Clock.fixed(pinned), () async {
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: GardenScreen())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2 days kept · 2 running'), findsOneWidget,
          reason: 'the streak must run against the pinned today');
    });

    await unmountAndDrainDrift(tester);
  });

  testWidgets('HabitDetailScreen computes the running streak from the '
      'pinned day', (tester) async {
    final id = await repo.createHabit(name: 'Walk', cadence: Cadence.binary);
    final habit = (await repo.getHabit(id))!;
    await repo.setBinary(habit, DateTime(2026, 7, 12).toDateDay(), true);
    await repo.setBinary(habit, pinned.toDateDay(), true);

    await withClock(Clock.fixed(pinned), () async {
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: HabitDetailScreen(habitId: id)),
      ));
      await tester.pumpAndSettle();

      // Running / Best / Kept are all 2 under the pinned clock; under the
      // wall clock Running would be 0.
      expect(find.text('0'), findsNothing,
          reason: 'a zero stat means the running streak was computed '
              'against the wall clock, not the pinned today');
      expect(find.text('2'), findsWidgets);
    });

    await unmountAndDrainDrift(tester);
  });
}
