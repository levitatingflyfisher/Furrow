import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:furrow/core/router/app_shell.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/presentation/habit_detail_screen.dart';
import 'package:furrow/features/habits/presentation/today_screen.dart';
import 'package:furrow/features/settings/presentation/settings_screen.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';

/// The fleet delete ruling in Furrow: a delete that is already deliberate
/// (a menu item, a row's own x) does not ask. It happens, and an Undo that
/// never times out offers it back. The one hard delete (Delete forever, in
/// Settings' Recently removed) is confirmed with a label naming the act.
final _theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB07A2E)),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<GoRouter> _pump(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/habit/:id',
        builder: (_, s) => HabitDetailScreen(habitId: s.pathParameters['id']!),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        backupReminderStoreProvider.overrideWithValue(
          InMemoryBackupReminderStore(),
        ),
      ],
      child: MaterialApp.router(theme: _theme, routerConfig: router),
    ),
  );
  await _settle(tester);
  return router;
}

/// Real database work cannot finish inside the test's fake-async zone
/// (drift's stream queries wait on timers), so every query runs in runAsync.
Future<T> _q<T>(WidgetTester tester, Future<T> Function() f) async =>
    (await tester.runAsync(f)) as T;

Future<void> _closeDb(WidgetTester tester, AppDatabase db) async {
  await db.close();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late AppDatabase db;
  late HabitsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
  });

  testWidgets('Remove does not ask; the shell offers Undo, which restores', (
    tester,
  ) async {
    final id = await _q(
      tester,
      () => repo.createHabit(name: 'Walk', cadence: Cadence.binary),
    );
    final router = await _pump(tester, db);

    router.push('/habit/$id');
    await _settle(tester);
    // The bar's actions are worded: Edit, and a More menu of named items.
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Edit')),
        findsOneWidget);
    await tester.tap(find.byTooltip('More'));
    await _settle(tester);
    await tester.tap(find.text('Remove'));
    await _settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(await _q(tester, () => repo.watchActive().first), isEmpty);
    expect(find.text('Removed Walk'), findsOneWidget);

    // The nav bar owns the bottom inset; the undo strip must not add its
    // own gesture-bar band above it.
    tester.view.padding = const FakeViewPadding(bottom: 48);
    await tester.pump();
    final bar = tester.getSize(find.byType(OhUndoBar));
    tester.view.resetPadding();
    await tester.pump();
    expect(bar.height, lessThan(80), reason: 'no inset band in the strip');

    // No timer: an hour later the offer is still there.
    await tester.pump(const Duration(hours: 1));
    expect(find.text('Removed Walk'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(
      (await _q(tester, () => repo.watchActive().first)).map((h) => h.id),
      [id],
    );
    await _closeDb(tester, db);
  });

  testWidgets('Clear history does not ask and Undo puts every mark back', (
    tester,
  ) async {
    final id = await _q(
      tester,
      () => repo.createHabit(name: 'Walk', cadence: Cadence.binary),
    );
    final h = (await _q(tester, () => repo.getHabit(id)))!;
    await _q(tester, () => repo.setBinary(h, '2026-07-01', true));
    await _q(tester, () => repo.setBinary(h, '2026-07-02', true));
    final router = await _pump(tester, db);

    router.push('/habit/$id');
    await _settle(tester);
    await tester.tap(find.byTooltip('More'));
    await _settle(tester);
    await tester.tap(find.text('Clear history'));
    await _settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(await _q(tester, () => repo.watchMarksForHabit(id).first), isEmpty);
    expect(find.textContaining('Cleared 2 marks'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(
      await _q(tester, () => repo.watchMarksForHabit(id).first),
      hasLength(2),
    );
    await _closeDb(tester, db);
  });

  testWidgets("A mark's own x removes it with Undo", (tester) async {
    final id = await _q(
      tester,
      () => repo.createHabit(name: 'Walk', cadence: Cadence.binary),
    );
    final h = (await _q(tester, () => repo.getHabit(id)))!;
    await _q(tester, () => repo.setBinary(h, '2026-07-01', true));
    final router = await _pump(tester, db);

    router.push('/habit/$id');
    await _settle(tester);
    await tester.tap(find.byTooltip('Remove this mark'));
    await _settle(tester);
    expect(await _q(tester, () => repo.watchMarksForHabit(id).first), isEmpty);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(
      await _q(tester, () => repo.watchMarksForHabit(id).first),
      hasLength(1),
    );
    await _closeDb(tester, db);
  });

  testWidgets('Recently removed: Restore, and a confirmed Delete forever', (
    tester,
  ) async {
    final a = await _q(
      tester,
      () => repo.createHabit(name: 'Walk', cadence: Cadence.binary),
    );
    final b = await _q(
      tester,
      () => repo.createHabit(name: 'Read', cadence: Cadence.binary),
    );
    await _q(tester, () => repo.removeHabit(a));
    await _q(tester, () => repo.removeHabit(b));
    final router = await _pump(tester, db);
    router.go('/settings');
    await _settle(tester);

    expect(find.text('Recently removed'), findsOneWidget);
    await tester.ensureVisible(find.byKey(Key('restore-$a')));
    await tester.tap(find.byKey(Key('restore-$a')));
    await _settle(tester);
    expect(
      (await _q(tester, () => repo.watchActive().first)).map((h) => h.id),
      [a],
    );

    await tester.ensureVisible(find.byKey(Key('forever-$b')));
    await tester.tap(find.byKey(Key('forever-$b')));
    await _settle(tester);
    expect(find.text('Delete Read forever'), findsOneWidget);
    await tester.tap(find.text('Delete Read forever'));
    await _settle(tester);
    expect(await _q(tester, () => repo.getHabit(b)), isNull);
    await _closeDb(tester, db);
  });
}
