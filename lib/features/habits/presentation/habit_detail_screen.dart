// lib/features/habits/presentation/habit_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/features/habits/presentation/log_time_sheet.dart';
import 'package:furrow/shared/extensions/duration_ext.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(habitsRepositoryProvider);
    return StreamBuilder<Habit?>(
      stream: repo.watchHabit(habitId),
      builder: (context, snap) {
        final habit = snap.data;
        if (habit == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return _Detail(habit: habit);
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marksAsync = ref.watch(marksForHabitProvider(habit.id));
    final cadence = Cadence.fromName(habit.cadence);
    final color = Color(habit.colorValue);
    final today = DateTime.now();

    Future<void> confirmDelete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Remove ${habit.name}?'),
          content: const Text('This deletes the habit and all its marks.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove')),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(habitsRepositoryProvider).deleteHabit(habit.id);
        if (context.mounted) context.pop();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil),
            onPressed: () => context.push('/habit/${habit.id}/edit'),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            onPressed: confirmDelete,
          ),
        ],
      ),
      body: marksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (marks) {
          final streak = currentStreak(habit, marks, today);
          final best = bestStreak(habit, marks);
          final kept = completedDayCount(habit, marks);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  _StatCard(label: 'Running', value: '$streak', color: color),
                  const SizedBox(width: AppSpacing.sm),
                  _StatCard(label: 'Best', value: '$best', color: color),
                  const SizedBox(width: AppSpacing.sm),
                  _StatCard(label: 'Days kept', value: '$kept', color: color),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (cadence == Cadence.duration)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: () => showLogTimeSheet(context, habit),
                  icon: const Icon(LucideIcons.timer),
                  label: Text('Log time toward '
                      '${(habit.targetValue / 60).round()} min'),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text('Recent', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (marks.isEmpty)
                Text('No marks yet.',
                    style: Theme.of(context).textTheme.bodyMedium)
              else
                ...marks.take(30).map((m) => _MarkTile(habit: habit, mark: m)),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          child: Column(
            children: [
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkTile extends StatelessWidget {
  const _MarkTile({required this.habit, required this.mark});
  final Habit habit;
  final HabitMark mark;
  @override
  Widget build(BuildContext context) {
    final cadence = Cadence.fromName(habit.cadence);
    final trailing = switch (cadence) {
      Cadence.binary => mark.completed ? 'done' : '—',
      Cadence.count => '${mark.value}${habit.unit != null ? ' ${habit.unit}' : ''}',
      Cadence.duration =>
        Duration(seconds: mark.durationSecs ?? 0).toHoursLabel(),
    };
    return ListTile(
      dense: true,
      leading: Icon(
        mark.completed ? LucideIcons.check : LucideIcons.minus,
        size: 18,
        color: Color(habit.colorValue),
      ),
      title: Text(mark.dateDay),
      trailing: Text(trailing),
    );
  }
}
