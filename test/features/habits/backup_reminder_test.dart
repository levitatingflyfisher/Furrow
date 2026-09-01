import 'dart:io';

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
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';

/// First run opens into the task; unfinished backup setup is a quiet,
/// dismissable line on Today rather than a gate (fleet ruling 48).
Future<T> _q<T>(WidgetTester t, Future<T> Function() f) async =>
    (await t.runAsync(f)) as T;

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  testWidgets('Today shows the Finish setup line until dismissed',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    await _q(tester,
        () => repo.createHabit(name: 'Walk', cadence: Cadence.binary));

    await tester.pumpWidget(ProviderScope(
      overrides: [
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
      ],
      child: const MaterialApp(home: Scaffold(body: TodayScreen())),
    ));
    await _settle(tester);

    expect(find.textContaining("Backup isn't set up"), findsOneWidget);
    expect(find.text('Walk'), findsOneWidget); // the task is right there
    await tester.tap(find.text('Dismiss'));
    await _settle(tester);
    expect(find.textContaining("Backup isn't set up"), findsNothing);

    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });

  test('main scopes the recovery words to Furrow on the web', () {
    // A claim with a check: without this override every fleet PWA on one
    // origin shares the same localStorage keys for its recovery words.
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('appScopedKeyStoreOverride()'));
  });
}
