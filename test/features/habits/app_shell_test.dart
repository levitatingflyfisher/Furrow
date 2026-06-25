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
}
