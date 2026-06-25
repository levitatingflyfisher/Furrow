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
import 'package:furrow/shared/extensions/datetime_ext.dart';
import 'package:furrow/shared/theme/app_colors.dart';

import 'visual_golden_helper.dart';

// A plain (Roboto) theme with Furrow's real colour scheme — avoids the
// google_fonts runtime-fetch path in headless goldens while keeping the layout
// and palette faithful. (The live app uses the google_fonts theme; fonts load
// from the CDN there.)
final _theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.furrow500,
    surface: AppColors.linen100,
    onSurface: AppColors.linen900,
  ),
  scaffoldBackgroundColor: AppColors.linen100,
);

void main() {
  testWidgets('Today grid — three cadences + virtue, swept sizes/text-scale',
      (tester) async {

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    // A binary habit kept most of the week (a furrow cut clean).
    final walkId = await repo.createHabit(
        name: 'Walk the dog', cadence: Cadence.binary, colorValue: 0xFF5E9478);
    final walk = (await repo.getHabit(walkId))!;
    for (final i in [0, 1, 2, 3]) {
      await repo.setBinary(walk, monday.add(Duration(days: i)).toDateDay(), true);
    }
    // A count habit, part-way today.
    final waterId = await repo.createHabit(
        name: 'Water',
        cadence: Cadence.count,
        targetValue: 8,
        unit: 'glasses',
        colorValue: 0xFF5C7599);
    await repo.adjustCount((await repo.getHabit(waterId))!, today.toDateDay(), 5);
    // A duration habit with a long name (ellipsis stress).
    final readId = await repo.createHabit(
        name: 'Read before bed, even a page',
        cadence: Cadence.duration,
        targetValue: 20 * 60,
        colorValue: 0xFFB07A2E);
    await repo.addDurationSession((await repo.getHabit(readId))!,
        today.toDateDay(),
        startMillis: 0, endMillis: 0, durationSecs: 12 * 60);
    // A virtue habit to surface the virtue-of-the-week banner.
    final tempId = await repo.createHabit(
        name: 'Temperance', cadence: Cadence.binary, virtueKey: 'temperance');
    await repo.setBinary((await repo.getHabit(tempId))!, today.toDateDay(), true);

    await goldenAtSizes(
      tester,
      name: 'today',
      theme: _theme,
      sizes: const {'phone': Size(360, 820), 'tablet': Size(768, 1024)},
      textScales: const [1.0, 2.0],
      home: ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const Scaffold(body: TodayScreen()),
      ),
    );
  });

  testWidgets('Today empty state renders the calm prompt (no habits)',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await goldenAtSizes(
      tester,
      name: 'today_empty',
      theme: _theme,
      sizes: const {'phone': Size(360, 740)},
      home: ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const Scaffold(body: TodayScreen()),
      ),
    );
  });
}
