import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/features/habits/presentation/award_recheck.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';
import 'package:furrow/shared/theme/app_colors.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

/// The evening review — Franklin's actual loop. One pass down the day's
/// rows with thumb-sized controls, any evening (or the morning after; the
/// day chips reach back a week — catching up is normal here).
///
/// No dark patterns, deliberately: nothing nags you to review, skipping a
/// habit writes nothing, and the copy never scolds. The grid on Today is
/// the beautiful OUTPUT of this moment, not the input surface.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late String _dateDay;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    final now = clock.now();
    _today = DateTime(now.year, now.month, now.day);
    _dateDay = _today.toDateDay();
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    final marksAsync = ref.watch(marksForDayProvider(_dateDay));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evening review'),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => context.pop(),
        ),
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load habits.\n$e')),
        data: (habits) {
          final day = DateTime.parse(_dateDay);
          final scheduled =
              habits.where((h) => isScheduledOn(h, day)).toList();
          final marks = marksAsync.value ?? const <HabitMark>[];
          return Column(
            children: [
              _DayChips(
                today: _today,
                selected: _dateDay,
                onSelect: (d) => setState(() => _dateDay = d),
              ),
              Expanded(
                child: scheduled.isEmpty
                    ? Center(
                        child: Text('Nothing scheduled this day.',
                            style: Theme.of(context).textTheme.bodyMedium),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                            AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
                        itemCount: scheduled.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) => _ReviewCard(
                          habit: scheduled[i],
                          dateDay: _dateDay,
                          marks: marks
                              .where((m) => m.habitId == scheduled[i].id)
                              .toList(),
                        ),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.pop(),
                      child: const Text('Done — field tended'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The last seven days as chips — reviewing yesterday (or Tuesday) is a
/// first-class path, not a correction.
class _DayChips extends StatelessWidget {
  const _DayChips({
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final DateTime today;
  final String selected;
  final ValueChanged<String> onSelect;

  static const _weekdayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', // 1..7
  ];

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(today.year, today.month, today.day - i)
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final d = days[i];
          final key = d.toDateDay();
          final label = i == 0
              ? 'Today'
              : i == 1
                  ? 'Yesterday'
                  : _weekdayNames[d.weekday - 1];
          return ChoiceChip(
            label: Text(label),
            selected: key == selected,
            onSelected: (_) => onSelect(key),
          );
        },
      ),
    );
  }
}

/// One habit's row in the review: the name, the day's state, and a control
/// sized for a thumb — never smaller than 44dp.
class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({
    required this.habit,
    required this.dateDay,
    required this.marks,
  });

  final Habit habit;
  final String dateDay;
  final List<HabitMark> marks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(habitsRepositoryProvider);
    final color = Color(habit.colorValue);
    final day = DateTime.parse(dateDay);
    final progress = dayProgress(habit, marks, day);
    final done = progress >= 1.0;

    Widget control;
    switch (Cadence.fromName(habit.cadence)) {
      case Cadence.binary:
        control = SizedBox(
          height: 44,
          child: done
              ? OutlinedButton.icon(
                  onPressed: () async {
                    await repo.setBinary(habit, dateDay, false);
                    await recheckAwards(ref);
                  },
                  icon: const Icon(LucideIcons.undo2, size: 18),
                  label: const Text('Undo'),
                )
              : FilledButton.icon(
                  onPressed: () async {
                    await repo.setBinary(habit, dateDay, true);
                    await recheckAwards(ref);
                  },
                  icon: const Icon(LucideIcons.check, size: 18),
                  label: const Text('Done'),
                ),
        );
      case Cadence.count:
        final count = marks.fold<int>(0, (sum, m) => sum + m.value);
        control = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.outlined(
              iconSize: 20,
              constraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: count > 0
                  ? () async {
                      await repo.adjustCount(habit, dateDay, -1);
                      await recheckAwards(ref);
                    }
                  : null,
              icon: const Icon(LucideIcons.minus),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text('$count',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton.filled(
              iconSize: 20,
              constraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () async {
                await repo.adjustCount(habit, dateDay, 1);
                await recheckAwards(ref);
              },
              icon: const Icon(LucideIcons.plus),
            ),
          ],
        );
      case Cadence.duration:
        final minutes =
            marks.fold<int>(0, (sum, m) => sum + m.value) ~/ 60;
        control = Wrap(
          spacing: AppSpacing.xs,
          children: [
            if (minutes > 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Chip(label: Text('$minutes min')),
              ),
            for (final add in const [5, 15, 30])
              ActionChip(
                label: Text('+$add'),
                onPressed: () async {
                  final end = clock.now().millisecondsSinceEpoch;
                  await repo.addDurationSession(
                    habit,
                    dateDay,
                    startMillis: end - add * 60 * 1000,
                    endMillis: end,
                    durationSecs: add * 60,
                  );
                  await recheckAwards(ref);
                },
              ),
          ],
        );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: done ? 1 : 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(habit.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(width: AppSpacing.sm),
            control,
          ],
        ),
      ),
    );
  }
}

/// The calm doorway on Today: an invitation, never a nag — no badge, no
/// count of "missed" anything.
class ReviewDoorCard extends StatelessWidget {
  const ReviewDoorCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/review'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(LucideIcons.moonStar,
                  size: 22, color: AppColors.furrow500),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Evening review',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'Walk the day in one pass — big buttons, any day '
                      'this week.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
