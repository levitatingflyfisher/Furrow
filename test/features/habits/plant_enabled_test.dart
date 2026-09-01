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
}
