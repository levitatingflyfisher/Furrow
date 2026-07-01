// lib/features/habits/presentation/today_screen.dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/focus_override_store.dart';
import 'package:furrow/features/habits/domain/franklin_virtues.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/features/habits/presentation/award_recheck.dart';
import 'package:furrow/features/habits/presentation/furrow_row.dart';
import 'package:furrow/features/habits/presentation/log_time_sheet.dart';
import 'package:furrow/features/habits/presentation/review_screen.dart';
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

    // package:clock, not DateTime.now(): tests (goldens especially) pin the
    // date with withClock, so the week strip renders deterministically.
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    // Calendar-safe week strip: DateTime(y, m, d + i) instead of Duration
    // math, which can land on 23:00 of the wrong day across a DST change.
    final monday = today.startOfWeek;
    final weekDays = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i)
    ];

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
    final focusAsync = ref.watch(focusVirtueProvider(todayKey));
    final focus = focusAsync.value;

    // The week's focus virtue leads the field; everything else keeps its
    // planted order.
    final ordered = [
      if (focus != null) ...habits.where((h) => h.virtueKey == focus.key),
      ...habits.where((h) => focus == null || h.virtueKey != focus.key),
    ];

    List<HabitMark> marksOf(Habit h) =>
        allMarks.where((m) => m.habitId == h.id).toList();

    Future<void> checkAwards() => recheckAwards(ref);

    // Tap (today only): log today inline — toggle, +1, or the time sheet.
    Future<void> tapDay(Habit h, DateTime day) async {
      final key = day.toDateDay();
      switch (Cadence.fromName(h.cadence)) {
        case Cadence.binary:
          final done = completedDayKeys(h, marksOf(h)).contains(key);
          await repo.setBinary(h, key, !done);
          await checkAwards();
        case Cadence.count:
          await repo.adjustCount(h, key, 1);
          await checkAwards();
        case Cadence.duration:
          if (context.mounted) await showLogTimeSheet(context, h);
      }
    }

    // Long-press: count "undo" (−1) and the time sheet are today-only; binary
    // toggles ANY non-future day, so a forgotten tick on a past day is fixed
    // inline without opening a screen.
    Future<void> longPressDay(Habit h, DateTime day) async {
      final key = day.toDateDay();
      switch (Cadence.fromName(h.cadence)) {
        case Cadence.count:
          await repo.adjustCount(h, key, -1);
          await checkAwards();
        case Cadence.binary:
          final done = completedDayKeys(h, marksOf(h)).contains(key);
          await repo.setBinary(h, key, !done);
          await checkAwards();
        case Cadence.duration:
          if (context.mounted) await showLogTimeSheet(context, h);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
      children: [
        if (virtueHabits.isNotEmpty) _VirtueBanner(now: today),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                // Weekday letters share the cells' exact layout (7 Expanded
                // columns inside the same horizontal padding), so alignment
                // is structural — it cannot drift.
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
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
                                    fontWeight:
                                        weekDays[i].toDateDay() == todayKey
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var i = 0; i < ordered.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.4)),
                  FurrowRow(
                    habit: ordered[i],
                    weekDays: weekDays,
                    marks: marksOf(ordered[i]),
                    today: today,
                    onTapDay: (day) => tapDay(ordered[i], day),
                    onLongPressDay: (day) => longPressDay(ordered[i], day),
                    onOpen: () => context.push('/habit/${ordered[i].id}'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const ReviewDoorCard(),
      ],
    );
  }
}

/// The week's focus virtue, override-aware, keyed by today's date-day so it
/// flips at midnight with the rest of the surface.
final focusVirtueProvider = FutureProvider.autoDispose
    .family<Virtue, String>((ref, todayKey) async {
  final db = ref.watch(appDatabaseProvider);
  final today = DateTime.parse(todayKey);
  final overrideKey =
      await FocusOverrideStore(db).overrideFor(today.startOfWeek);
  final anchor = DateTime(today.year, 1, 1).startOfWeek;
  return focusVirtueForWeek(
      anchorMonday: anchor, now: today, overrideKey: overrideKey);
});

class _VirtueBanner extends ConsumerWidget {
  const _VirtueBanner({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayKey = now.toDateDay();
    final focus = ref.watch(focusVirtueProvider(todayKey)).value;
    if (focus == null) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pickFocus(context, ref, focus),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.furrow500.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.furrow500.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Expanded(
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
                    Text(focus.name,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(focus.precept,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronDown, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// Choose this week's focus — Franklin picked deliberately, and so can
  /// the household. "Follow the rotation" returns to the classic 13-week
  /// cycle next tap.
  Future<void> _pickFocus(
      BuildContext context, WidgetRef ref, Virtue current) async {
    final todayKey = now.toDateDay();
    final monday = now.startOfWeek;
    final db = ref.read(appDatabaseProvider);
    final rotation =
        virtueOfWeek(DateTime(now.year, 1, 1).startOfWeek, now);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ListView(
        children: [
          ListTile(
            leading: const Icon(LucideIcons.refreshCw,
                size: 18, color: AppColors.furrow500),
            title: const Text('Follow the rotation'),
            subtitle: Text('This week that means ${rotation.name}.'),
            onTap: () async {
              await FocusOverrideStore(db).clearOverride(monday);
              ref.invalidate(focusVirtueProvider(todayKey));
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            },
          ),
          const Divider(height: 1),
          for (final v in kFranklinVirtues)
            ListTile(
              selected: v.key == current.key,
              title: Text(v.name),
              subtitle: Text(v.precept,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () async {
                await FocusOverrideStore(db).setOverride(monday, v.key);
                ref.invalidate(focusVirtueProvider(todayKey));
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
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
