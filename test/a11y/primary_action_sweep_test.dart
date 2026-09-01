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
import 'package:furrow/features/habits/presentation/habit_edit_sheet.dart';
import 'package:furrow/features/habits/presentation/today_screen.dart';
import 'package:furrow/shared/theme/app_theme.dart';
import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';

/// The release gate for Furrow's primary-action screens (C5-primaryScreens):
/// at 360dp x 1.3 text the primary action is on screen and tappable, and at
/// 320dp x 3.0 nothing overflows. Rendered with the real AppTheme, so the
/// 0.7.0 type ladder (body 16) is what is being measured.
List<Override> _overrides(AppDatabase db) => [
      appDatabaseProvider.overrideWithValue(db),
      secureKeyStoreProvider.overrideWithValue(InMemorySecureKeyStore()),
      cryptoServiceProvider.overrideWithValue(FakeCryptoService()),
      sanctuaryAppDomainProvider.overrideWithValue('furrow'),
      sanctuaryBackupConfigProvider.overrideWithValue(
        const SanctuaryBackupConfig(
          appId: 'furrow',
          aadContext: 'furrow-backup/v1',
          appDisplayName: 'Furrow',
        ),
      ),
      backupReminderStoreProvider
          .overrideWithValue(InMemoryBackupReminderStore()),
    ];

/// Let drift's queries emit outside the fake clock, then rebuild.
Future<void> _load(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('Today (in the shell): today\'s cell is reachable', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    final ids = <String>[];
    await tester.runAsync(() async {
      // A realistic field: the three starters plus a long name.
      ids.add(await repo.createHabit(name: 'Move', cadence: Cadence.binary));
      await repo.createHabit(
          name: 'Read', cadence: Cadence.duration, targetValue: 1200);
      await repo.createHabit(
          name: 'Water',
          cadence: Cadence.count,
          targetValue: 8,
          unit: 'glasses');
      await repo.createHabit(
          name: 'Tidy the kitchen before bed', cadence: Cadence.binary);
    });

    await runPrimaryActionSweep(
      tester,
      pumpScreen: () async {
        final router = GoRouter(
          initialLocation: '/today',
          routes: [
            ShellRoute(
              builder: (_, __, child) => AppShell(child: child),
              routes: [
                GoRoute(
                    path: '/today', builder: (_, __) => const TodayScreen()),
              ],
            ),
          ],
        );
        await tester.pumpWidget(ProviderScope(
          overrides: _overrides(db),
          child:
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ));
        await _load(tester);
      },
      primaryAction: find.byKey(ValueKey('today_${ids.first}')),
    );
    expect(find.text('Plant'), findsOneWidget);
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Plant a habit: the Plant action is reachable', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await runPrimaryActionSweep(
      tester,
      pumpScreen: () async {
        await tester.pumpWidget(ProviderScope(
          overrides: _overrides(db),
          child: MaterialApp(
              theme: AppTheme.light, home: const HabitEditSheet()),
        ));
        await _load(tester);
      },
      primaryAction: find.widgetWithText(TextButton, 'Plant'),
    );
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });
}
