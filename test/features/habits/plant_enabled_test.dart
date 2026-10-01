import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/presentation/habit_edit_sheet.dart';

/// "Plant" over an empty name rippled and silently dropped the request
/// (furrow:design-of-everyday-things-04). The constraint is shown before
/// the tap instead: Plant stays disabled until the name has a letter in it.
void main() {
  testWidgets('Plant is disabled while the name is empty or blank',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: HabitEditSheet()),
    ));
    await tester.pump();

    TextButton plant() =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Plant'));

    expect(plant().onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    expect(plant().onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, 'Read');
    await tester.pump();
    expect(plant().onPressed, isNotNull);

    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });

  // doet-04, second half: the commit was only a bare app-bar word while
  // eight colour circles dominated the form. A full-width filled Plant now
  // closes the form, under the same rule (live only with a name).
  testWidgets('a full-width Plant button sits at the foot of the form',
      (tester) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: HabitEditSheet()),
    ));
    await tester.pump();

    final foot = find.ancestor(
      of: find.text('Plant'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(foot, findsOneWidget);
    expect(tester.getSize(foot).width, greaterThanOrEqualTo(360 - 2 * 16 - 1));
    FilledButton button() => tester.widget<FilledButton>(foot);
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, 'Read');
    await tester.pump();
    expect(button().onPressed, isNotNull);

    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });

  // mind-in-mind-15, the picker half: the "Some days" chips were single
  // letters too (two Ts, two Ss). They use the grid's two-letter names.
  testWidgets('the Some days picker names each day in two letters',
      (tester) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: HabitEditSheet()),
    ));
    await tester.pump();
    await tester.tap(find.text('Some days'));
    await tester.pump();
    for (final d in const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']) {
      expect(find.widgetWithText(FilterChip, d), findsOneWidget, reason: d);
    }

    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });
}
