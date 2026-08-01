import 'package:clock/clock.dart';
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
import 'package:furrow/features/habits/presentation/review_screen.dart';
import 'package:furrow/shared/theme/app_theme.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Regression guard for the ohStyle/Flutter 3.38.7 icon-button theme
/// collision documented in `openhearth_design`'s `icon_buttons.dart` and
/// enforced fleet-wide by conformance check C8: an app-wide
/// `ThemeData.iconTheme` pinned to `primary` is injected ABOVE a bare
/// `IconButton.filled`'s own defaults, painting its glyph the same color
/// it just filled its own background with.
///
/// Furrow's own `AppTheme` (`lib/shared/theme/app_theme.dart`) never sets
/// that ambient override — it leaves `ThemeData.iconTheme` at Flutter's
/// own default, which the framework's `IconButton.themeStyleOf` treats as
/// "no override" and lets the widget's own `onPrimary` default win. So
/// the count-cadence '+' stepper already resolves correctly under
/// `AppTheme.light`/`.dark` today; those two cases below are a
/// characterization anchor, not a regression guard by themselves — they
/// pass with a bare `IconButton.filled` just as they do with
/// `OhIconButton.filled`.
///
/// The third case builds the actual hazard `OhIconButton` exists to
/// defeat: an ambient `iconTheme` explicitly pinned to `primary`, the
/// exact shape `OhTheme` sets fleet-wide. That is the one a bare
/// `IconButton.filled` fails and `OhIconButton.filled` passes — the real
/// RED→GREEN boundary for this fix.
void main() {
  Future<(AppDatabase, HabitsRepository)> seed() async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    await repo.createHabit(
        name: 'Pushups', cadence: Cadence.count, targetValue: 3);
    return (db, repo);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  final pinned = DateTime(2026, 7, 24, 20); // Friday evening

  Future<Color?> resolvedPlusColor(WidgetTester tester, ThemeData theme) async {
    final (db, _) = await seed();
    addTearDown(db.close);
    Color? resolved;
    await withClock(Clock.fixed(pinned), () async {
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: theme, home: const ReviewScreen()),
      ));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byIcon(LucideIcons.plus).last);
      resolved = IconTheme.of(ctx).color;
    });
    return resolved;
  }

  testWidgets('the + stepper resolves onPrimary under AppTheme.light',
      (tester) async {
    final resolved = await resolvedPlusColor(tester, AppTheme.light);
    expect(resolved, AppTheme.light.colorScheme.onPrimary);
    await unmount(tester);
  });

  testWidgets('the + stepper resolves onPrimary under AppTheme.dark',
      (tester) async {
    final resolved = await resolvedPlusColor(tester, AppTheme.dark);
    expect(resolved, AppTheme.dark.colorScheme.onPrimary);
    await unmount(tester);
  });

  testWidgets(
      'under an ambient iconTheme pinned to primary — the OhTheme shape — '
      'the + stepper still resolves onPrimary, never primary',
      (tester) async {
    final collision = AppTheme.light.copyWith(
      iconTheme: IconThemeData(color: AppTheme.light.colorScheme.primary),
    );
    final resolved = await resolvedPlusColor(tester, collision);
    expect(resolved, isNot(collision.colorScheme.primary),
        reason: 'the blank-circle bug: glyph color == fill color');
    expect(resolved, collision.colorScheme.onPrimary);
    await unmount(tester);
  });
}
