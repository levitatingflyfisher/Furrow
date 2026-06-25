// lib/features/habits/presentation/today_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/domain/franklin_virtues.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/features/habits/presentation/furrow_row.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';
import 'package:furrow/shared/theme/app_colors.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// The Today grid — Furrow's home surface. One [FurrowRow] per active habit,
/// showing this week (Mon..Sun) with today's cell live.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    final marksAsync = ref.watch(allMarksProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final weekDays = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];

    return habitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load habits.\n$e')),
      data: (habits) => marksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load marks.\n$e')),
        data: (allMarks) => habits.isEmpty
            ? const _EmptyField()
            : _Grid(
                habits: habits,
                allMarks: allMarks,
                weekDays: weekDays,
                today: today),
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({
    required this.habits,
    required this.allMarks,
    required this.weekDays,
    required this.today,
  });

  final List<Habit> habits;
  final List<HabitMark> allMarks;
  final List<DateTime> weekDays;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(habitsRepositoryProvider);
    final todayKey = today.toDateDay();
    final virtueHabits = habits.where((h) => h.virtueKey != null).toList();

    List<HabitMark> marksOf(Habit h) =>
        allMarks.where((m) => m.habitId == h.id).toList();

    Future<void> tapToday(Habit h) async {
      switch (Cadence.fromName(h.cadence)) {
        case Cadence.binary:
          final done = completedDayKeys(h, marksOf(h)).contains(todayKey);
          await repo.setBinary(h, todayKey, !done);
        case Cadence.count:
          await repo.adjustCount(h, todayKey, 1);
        case Cadence.duration:
          if (context.mounted) context.push('/habit/${h.id}');
      }
    }

    Future<void> longPressToday(Habit h) async {
      switch (Cadence.fromName(h.cadence)) {
        case Cadence.count:
          await repo.adjustCount(h, todayKey, -1);
        case Cadence.binary:
          final done = completedDayKeys(h, marksOf(h)).contains(todayKey);
          await repo.setBinary(h, todayKey, !done);
        case Cadence.duration:
          if (context.mounted) context.push('/habit/${h.id}');
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
      children: [
        if (virtueHabits.isNotEmpty) _VirtueBanner(now: today),
        // Weekday labels aligned over the seven cells.
        Padding(
          padding: const EdgeInsets.only(
              left: AppSpacing.sm, right: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Row(
            children: [
              const Expanded(child: SizedBox()),
              for (var i = 0; i < 7; i++)
                SizedBox(
                  width: 26,
                  child: Center(
                    child: Text(
                      _weekdayLetters[i],
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: weekDays[i].toDateDay() == todayKey
                                ? AppColors.furrow500
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.7),
                            fontWeight: weekDays[i].toDateDay() == todayKey
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < habits.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.4)),
                  FurrowRow(
                    habit: habits[i],
                    weekDays: weekDays,
                    marks: marksOf(habits[i]),
                    today: today,
                    onTapToday: () => tapToday(habits[i]),
                    onLongPressToday: () => longPressToday(habits[i]),
                    onOpen: () => context.push('/habit/${habits[i].id}'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VirtueBanner extends StatelessWidget {
  const _VirtueBanner({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // Anchor the rotation to the Monday of the first ISO week of this year.
    final anchor = DateTime(now.year, 1, 1);
    final v = virtueOfWeek(
        anchor.subtract(Duration(days: anchor.weekday - 1)), now);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.furrow500.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.furrow500.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THIS WEEK',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.furrow600,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 2),
          Text(v.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(v.precept,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _EmptyField extends StatelessWidget {
  const _EmptyField();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sprout,
                size: 48,
                color: AppColors.furrow500.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.md),
            Text('A clean field.',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Plant your first habit and tend it, one day at a time.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push('/habit/new'),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Plant a habit'),
            ),
          ],
        ),
      ),
    );
  }
}
