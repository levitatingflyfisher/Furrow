import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/presentation/review_screen.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// The evening review — one pass, thumb-sized controls, no dark patterns:
/// skipping writes nothing, reviewing yesterday is first-class, and the
/// controls reflect the ledger live.
void main() {
  Future<(AppDatabase, HabitsRepository)> seed() async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    await repo.createHabit(name: 'Morning pages', cadence: Cadence.binary);
    await repo.createHabit(
        name: 'Pushups', cadence: Cadence.count, targetValue: 3);
    return (db, repo);
  }

  Widget host(AppDatabase db) => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ReviewScreen()),
      );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  final pinned = DateTime(2026, 7, 24, 20); // Friday evening

  testWidgets('walks the day: big Done for binary, steppers for count',
      (tester) async {
    final (db, _) = await seed();
    addTearDown(db.close);

    await withClock(Clock.fixed(pinned), () async {
      await tester.pumpWidget(host(db));
      await tester.pumpAndSettle();

      expect(find.text('Morning pages'), findsOneWidget);
      expect(find.text('Pushups'), findsOneWidget);

      // Binary: one big Done → becomes Undo (state reflects the ledger).
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsOneWidget);

      // Count: two + taps → the running value shows 2.
      final plus = find.byIcon(LucideIcons.plus).last;
      await tester.tap(plus);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
    });
    await unmount(tester);
  });

  testWidgets('yesterday is a chip away, and its marks land on yesterday',
      (tester) async {
    final (db, repo) = await seed();
    addTearDown(db.close);

    await withClock(Clock.fixed(pinned), () async {
      await tester.pumpWidget(host(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yesterday'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final marks = await repo.allMarksOnce();
      expect(marks.single.dateDay, '2026-07-23',
          reason: 'reviewing yesterday writes on yesterday');
    });
    await unmount(tester);
  });
}
