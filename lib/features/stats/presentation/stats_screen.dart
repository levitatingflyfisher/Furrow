// lib/features/stats/presentation/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/habits/domain/awards.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/shared/theme/app_colors.dart';
import 'package:furrow/shared/theme/app_spacing.dart';
import 'package:furrow/shared/widgets/load_failure.dart';

/// Calm stats: raw keeping counts (no percentages, no bars) + the award shelf.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    final marksAsync = ref.watch(allMarksProvider);
    final awardsAsync = ref.watch(awardsProvider);

    return habitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => loadFailure(e, st,
          title: "Couldn’t load your habits",
          onRetry: () => ref.invalidate(activeHabitsProvider)),
      data: (habits) => marksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => loadFailure(e, st,
            title: "Couldn’t load your marks",
            onRetry: () => ref.invalidate(allMarksProvider)),
        data: (allMarks) {
          final totalKept = habits.fold<int>(
            0,
            (sum, h) => sum +
                completedDayCount(
                    h, allMarks.where((m) => m.habitId == h.id).toList()),
          );
          final earned = {
            for (final a in (awardsAsync.valueOrNull ?? []))
              if (a.earnedAt != null) a.id
          };
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _BigStat(
                value: '$totalKept',
                label: totalKept == 1 ? 'day kept' : 'days kept, all told',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Awards', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final a in kAwardMeta)
                _AwardRow(meta: a, earned: earned.contains(a.id)),
              const SizedBox(height: AppSpacing.lg),
              if (habits.isNotEmpty) ...[
                Text('By habit',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                for (final h in habits)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 8,
                      backgroundColor: Color(h.colorValue),
                    ),
                    title: Text(h.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                      '${completedDayCount(h, allMarks.where((m) => m.habitId == h.id).toList())} days',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: AppColors.furrow500)),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// One award, with what it takes and whether it is earned written out.
/// The criterion used to hide in a Tooltip, which a phone shows only on an
/// unannounced long-press; earned and not-yet differed only by opacity.
class _AwardRow extends StatelessWidget {
  const _AwardRow({required this.meta, required this.earned});
  final AwardMeta meta;
  final bool earned;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Earned reads in the ochre: the deep tone on light, the scheme's light
    // primary on dark, where furrow600 falls to about 3.5:1 (checked in
    // award_criteria_test for both themes).
    final ochre = theme.brightness == Brightness.dark
        ? cs.primary
        : AppColors.furrow600;
    final accent = earned ? ochre : cs.onSurfaceVariant;
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(meta.icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(meta.name, style: theme.textTheme.titleMedium),
                      Text(
                        earned ? 'Earned' : 'Not yet',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight:
                              earned ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(meta.description,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
