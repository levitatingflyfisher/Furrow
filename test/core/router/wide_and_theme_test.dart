import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/router/app_shell.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/presentation/today_screen.dart';
import 'package:furrow/features/settings/presentation/settings_screen.dart';
import 'package:furrow/shared/theme/app_theme.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';

/// The shell caps its content with OhPage on wide screens, and the theme is
/// one control (OhThemeToggle) in the top bar of every tab.
Future<T> _q<T>(WidgetTester t, Future<T> Function() f) async =>
    (await t.runAsync(f)) as T;

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _pump(WidgetTester tester, AppDatabase db, Size size,
    {String at = '/today'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: at,
    routes: [
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
          GoRoute(
              path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      backupReminderStoreProvider
          .overrideWithValue(InMemoryBackupReminderStore()),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ));
  await _settle(tester);
}

void main() {
  testWidgets('at 1024 px the Today grid is capped, not stretched',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    await _q(tester,
        () => repo.createHabit(name: 'Walk', cadence: Cadence.binary));
    await _pump(tester, db, const Size(1024, 768));

    expect(find.byType(OhPage), findsOneWidget);
    final grid = tester.getSize(find.byType(Card).first);
    expect(grid.width, lessThanOrEqualTo(OhPage.phoneMaxWidth));
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
      'the theme control is one OhThemeToggle in the top bar, and '
      'Settings has no second switch', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await _pump(tester, db, const Size(320, 640), at: '/settings');

    final bar = find.byType(AppBar);
    expect(find.descendant(of: bar, matching: find.byType(OhThemeToggle)),
        findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    // Top-bar actions carry a visible word, not just an icon (ruling 45).
    expect(
        find.descendant(of: bar, matching: find.text('Plant')), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget); // follows the phone by default

    await tester.tap(find.byType(OhThemeToggle));
    await _settle(tester);
    await tester.tap(find.text('Dark').last);
    await _settle(tester);
    expect(
        find.descendant(of: bar, matching: find.text('Dark')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });
}
