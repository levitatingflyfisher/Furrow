// lib/features/habits/presentation/garden_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

/// The field: every habit with its keeping so far. Tap one for its detail.
class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    final marksAsync = ref.watch(allMarksProvider);
    final today = DateTime.now();

    return habitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (habits) => marksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (allMarks) {
          if (habits.isEmpty) {
            return Center(
              child: Text('Nothing planted yet.',
                  style: Theme.of(context).textTheme.bodyLarge),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: habits.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final h = habits[i];
              final marks = allMarks.where((m) => m.habitId == h.id).toList();
              final kept = completedDayCount(h, marks);
              final streak = currentStreak(h, marks, today);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(h.colorValue).withValues(alpha: 0.18),
                    child: Icon(LucideIcons.sprout, color: Color(h.colorValue)),
                  ),
                  title: Text(h.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(streak > 0
                      ? '$kept days kept · $streak running'
                      : '$kept days kept'),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => context.push('/habit/${h.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
