// lib/features/habits/presentation/habit_detail_screen.dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/features/habits/presentation/log_time_sheet.dart';
import 'package:furrow/shared/extensions/duration_ext.dart';
import 'package:furrow/shared/theme/app_spacing.dart';
import 'package:furrow/shared/widgets/load_failure.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final String habitId;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  /// Undo for the deletes made on this screen (a mark, the whole history).
  /// No timer: the offer stays until Undo, Dismiss, the next delete, or
  /// leaving the screen (fleet delete ruling).
  final _undo = OhUndoController();

  @override
  void dispose() {
    _undo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(habitsRepositoryProvider);
    return StreamBuilder<Habit?>(
      stream: repo.watchHabit(widget.habitId),
      builder: (context, snap) {
        final habit = snap.data;
        if (habit == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return _Detail(habit: habit, undo: _undo);
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.habit, required this.undo});
  final Habit habit;
  final OhUndoController undo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marksAsync = ref.watch(marksForHabitProvider(habit.id));
    final cadence = Cadence.fromName(habit.cadence);
    final color = Color(habit.colorValue);
    final today = clock.now();
    final repo = ref.read(habitsRepositoryProvider);

    // Removing is chosen from a menu, so it is deliberate: no "are you
    // sure". The habit is soft-deleted, the shell offers Undo, and Settings'
    // Recently removed keeps the way back.
    Future<void> remove() async {
      await repo.removeHabit(habit.id);
      ref.read(habitUndoProvider).show(
            message: 'Removed ${habit.name}',
            onUndo: () => repo.restoreHabit(habit.id),
          );
      if (context.mounted) context.pop();
    }

    // Clear history keeps the habit and deletes its marks; Undo puts every
    // one back while this screen is open.
    Future<void> clearHistory() async {
      final gone = await repo.watchMarksForHabit(habit.id).first;
      if (gone.isEmpty) return;
      await repo.clearMarks(habit.id);
      undo.show(
        message: 'Cleared ${gone.length} '
            '${gone.length == 1 ? 'mark' : 'marks'} from ${habit.name}',
        onUndo: () => repo.restoreMarks(habit, gone),
      );
    }

    Future<void> deleteMark(HabitMark m) async {
      await repo.deleteMark(m.id);
      undo.show(
        message: 'Removed the mark for ${m.dateDay}',
        onUndo: () => repo.restoreMarks(habit, [m]),
      );
    }

    Future<void> toggleArchived() async {
      await ref
          .read(habitsRepositoryProvider)
          .setArchived(habit.id, !habit.archived);
      if (context.mounted) context.pop();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          OhBarActions(children: [
          OhBarAction(
            icon: LucideIcons.pencil,
            label: 'Edit',
            onPressed: () => context.push('/habit/${habit.id}/edit'),
          ),
          OhBarOverflow<String>(
            icon: LucideIcons.ellipsisVertical,
            onSelected: (value) => switch (value) {
              'archive' => toggleArchived(),
              'clear' => clearHistory(),
              'delete' => remove(),
              _ => Future<void>.value(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(habit.archived
                    ? 'Return to the field'
                    : 'Rest this habit'),
              ),
              const PopupMenuItem(
                  value: 'clear', child: Text('Clear history')),
              const PopupMenuItem(value: 'delete', child: Text('Remove')),
            ],
          ),
          ]),
        ],
      ),
      bottomNavigationBar: OhUndoBar(controller: undo),
      body: OhPage(
        padding: EdgeInsets.zero,
        child: marksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => loadFailure(e, st,
              title: "Couldn’t load this habit’s marks",
              onRetry: () => ref.invalidate(marksForHabitProvider(habit.id))),
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
                  ...marks.take(30).map((m) => _MarkTile(
                        habit: habit,
                        mark: m,
                        onDelete: () => deleteMark(m),
                      )),
              ],
            );
          },
        ),
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
  const _MarkTile(
      {required this.habit, required this.mark, required this.onDelete});
  final Habit habit;
  final HabitMark mark;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final cadence = Cadence.fromName(habit.cadence);
    final label = switch (cadence) {
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
      // A fat-fingered mark is no longer forever: every entry can go.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 16),
            tooltip: 'Remove this mark',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
