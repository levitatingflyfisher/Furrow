import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/awards_dao.dart';
import 'package:furrow/features/habits/domain/awards.dart';
import 'package:furrow/features/stats/presentation/stats_screen.dart';
import 'package:furrow/shared/theme/app_theme.dart';

/// Each award says what it takes, and whether it is earned, in words on the
/// screen (furrow:dont-make-me-think-06). The criterion used to live in a
/// Tooltip, which a phone only shows on a long-press nobody is told about.
void main() {
  testWidgets('every award shows its criterion and its state as text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() => AwardsDao(db).earn('first_mark', 1));

    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: StatsScreen())),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(Tooltip), findsNothing);
    for (final a in kAwardMeta) {
      expect(find.text(a.name), findsOneWidget);
      expect(find.text(a.description), findsOneWidget, reason: a.id);
    }
    expect(find.text('Earned'), findsOneWidget);
    expect(find.text('Not yet'), findsNWidgets(kAwardMeta.length - 1));

    // The written-out criteria wrap, not overflow, at 320dp x 3.0.
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });

  // The state words are 13 px text, so they need 4.5:1 on the screen's
  // ground in both themes (theme follows the phone by default, so dark is a
  // main path).
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('Earned / Not yet reach 4.5:1 in the $name theme',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() => AwardsDao(db).earn('first_mark', 1));
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
            theme: theme, home: const Scaffold(body: StatsScreen())),
      ));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump();

      double ratio(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      final ground = theme.scaffoldBackgroundColor;
      for (final word in ['Earned', 'Not yet']) {
        final color = tester.widget<Text>(find.text(word).first).style!.color!;
        expect(ratio(color, ground), greaterThanOrEqualTo(4.5),
            reason: '$word in $name');
      }
      await db.close();
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
