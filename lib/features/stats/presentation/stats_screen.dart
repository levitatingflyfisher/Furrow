// lib/features/stats/presentation/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/habits/domain/awards.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/shared/theme/app_colors.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

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
      error: (e, _) => Center(child: Text('$e')),
      data: (habits) => marksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
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
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final a in kAwardMeta)
                    _AwardChip(meta: a, earned: earned.contains(a.id)),
                ],
              ),
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

class _AwardChip extends StatelessWidget {
  const _AwardChip({required this.meta, required this.earned});
  final AwardMeta meta;
  final bool earned;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = earned ? AppColors.furrow500 : cs.onSurfaceVariant;
    return Tooltip(
      message: meta.description,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: earned
              ? AppColors.furrow500.withValues(alpha: 0.10)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: earned
                ? AppColors.furrow500.withValues(alpha: 0.4)
                : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(meta.icon,
                size: 16, color: color.withValues(alpha: earned ? 1 : 0.5)),
            const SizedBox(width: 6),
            Text(meta.name,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color.withValues(alpha: earned ? 1 : 0.6),
                    )),
          ],
        ),
      ),
    );
  }
}
