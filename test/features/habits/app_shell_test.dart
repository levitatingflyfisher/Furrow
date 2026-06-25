import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/router/app_shell.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';

// Plain theme (no google_fonts runtime fetch in headless tests).
final _theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB07A2E)),
);

void main() {
  // Regression: AppShell's Flow mode once collapsed the Today body to zero
  // height (a `Center` in the bottom bar expanded to eat the whole Scaffold),
  // leaving the grid blank. The body must render the seeded habit.
  testWidgets('AppShell (Flow) renders the Today grid, not a blank body',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    await repo.createHabit(name: 'Walk', cadence: Cadence.binary);

    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: _theme,
        home: const AppShell(child: SizedBox.shrink()),
      ),
    ));
    // Let the drift query emit, then rebuild. (No pumpAndSettle — the confetti
    // widget animates indefinitely.)
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Walk'), findsOneWidget,
        reason: 'the Today grid must render the seeded habit, not a blank body');
    expect(find.text('Flow'), findsOneWidget); // shell chrome present

    // Close the db (cancels drift's stream-query batch timer) and let the tree
    // settle so no timer is pending at teardown.
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });

  // The central "tracking" action: tapping today's cell records a completed
  // mark and the grid reflects it. (Exercises the tap→write→stream→rebuild
  // path end to end, which goldens/unit tests don't.)
  testWidgets('tapping today\'s cell records a completed mark', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    final walkId = await repo.createHabit(name: 'Walk', cadence: Cadence.binary);

    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: _theme,
        home: const AppShell(child: SizedBox.shrink()),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    var marks = await tester.runAsync(() => repo.allMarksOnce());
    expect(marks!.where((m) => m.completed).length, 0,
        reason: 'no marks before tapping');

    await tester.tap(find.byKey(ValueKey('today_$walkId')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    marks = await tester.runAsync(() => repo.allMarksOnce());
    expect(
      marks!.where((m) => m.completed && m.habitId == walkId).length,
      1,
      reason: 'tapping the cell must record one completed mark',
    );

    // The first mark earns the "First Light" award, which schedules the gentle
    // confetti + a snackbar + a delayed clear. Drain those timers so none are
    // pending at teardown.
    await tester.pump(const Duration(seconds: 6));
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });

  // Duration logging must NOT force a screen hop + a live stopwatch. Tapping a
  // duration cell opens a log sheet directly, and a quick-add chip records a
  // known duration in one tap. (Deterministic — no live Timer.periodic, so no
  // "timer still pending" teardown trap.)
  testWidgets('tapping a duration cell opens the log sheet; +15 logs 15 min',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    final readId = await repo.createHabit(
        name: 'Read', cadence: Cadence.duration, targetValue: 20 * 60);

    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: _theme,
        home: const AppShell(child: SizedBox.shrink()),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Tap today's duration cell — opens the log sheet, not a route push.
    await tester.tap(find.byKey(ValueKey('today_$readId')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150)); // sheet slides in
    }

    expect(find.byKey(const ValueKey('quickadd_15')), findsOneWidget,
        reason: 'the log sheet offers quick-add minutes up front');

    await tester.tap(find.byKey(const ValueKey('quickadd_15')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final marks = await tester.runAsync(() => repo.allMarksOnce());
    final logged = marks!.where((m) => m.habitId == readId).toList();
    expect(logged.length, 1, reason: 'one quick-add session logged');
    expect(logged.first.durationSecs, 15 * 60,
        reason: '+15 must record 15 minutes');

    await tester.pump(const Duration(seconds: 6)); // drain any award timers
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });

  // Editing a prior entry should not require a screen: long-pressing a past
  // binary day toggles that day inline. (On Mondays the week has no past day,
  // so the target collapses to today's cell — still the long-press toggle path.)
  testWidgets('long-pressing a past binary day records that day inline',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    final id = await repo.createHabit(name: 'Read', cadence: Cadence.binary);

    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: _theme,
        home: const AppShell(child: SizedBox.shrink()),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // The displayed week is Mon..Sun; target its Monday (a past day unless today
    // is Monday, in which case it's today's cell — both exercise the toggle).
    final now = DateTime.now();
    final todayD = DateTime(now.year, now.month, now.day);
    final monday = todayD.subtract(Duration(days: todayD.weekday - 1));
    final targetKey = monday.toDateDay();
    final keyStr = targetKey == todayD.toDateDay()
        ? 'today_$id'
        : 'day_${id}_$targetKey';

    await tester.longPress(find.byKey(ValueKey(keyStr)));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final marks = await tester.runAsync(() => repo.allMarksOnce());
    final hit = marks!.where(
        (m) => m.habitId == id && m.dateDay == targetKey && m.completed);
    expect(hit.length, 1,
        reason: 'long-press must toggle the targeted day done, inline');

    await tester.pump(const Duration(seconds: 6)); // drain award timers
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });
}
