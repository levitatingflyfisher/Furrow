// lib/features/settings/presentation/settings_screen.dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/habits/data/focus_override_store.dart';
import 'package:furrow/features/habits/domain/franklin_virtues.dart';
import 'package:furrow/features/sanctuary_backup/presentation/backup_section.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        ListTile(
          leading: const Icon(LucideIcons.bookOpen),
          title: const Text("Plant Franklin’s thirteen virtues"),
          subtitle: const Text(
              'This week’s virtue as a daily habit; the rest wait for their week'),
          onTap: () async {
            // Say what actually happened: planting twice plants nothing.
            final focus =
                await focusVirtueOn(ref.read(appDatabaseProvider), clock.now());
            final result = await ref
                .read(habitsRepositoryProvider)
                .seedFranklinVirtues(focusKey: focus.key);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(seedMessage(result)),
                behavior: SnackBarBehavior.floating,
              ));
            }
          },
        ),
        const _RestingHabits(),
        const _RecentlyRemoved(),
        const BackupSection(),
        const Divider(),
        const ListTile(
          leading: Icon(LucideIcons.info),
          title: Text('Furrow'),
          subtitle: Text(
              'We are what we repeatedly do.\nLocal-first: no ads, no account, no cloud.'),
        ),
      ],
    );
  }
}

/// Archived habits are resting, not gone — this is their way back to the
/// field. Renders nothing while every habit is active.
class _RestingHabits extends ConsumerWidget {
  const _RestingHabits();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resting = ref.watch(restingHabitsProvider).valueOrNull ?? const [];
    if (resting.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: Text('Resting',
              style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final h in resting)
          ListTile(
            leading: Icon(LucideIcons.sprout,
                size: 18, color: Color(h.colorValue)),
            title: Text(h.name),
            trailing: TextButton(
              onPressed: () => ref
                  .read(habitsRepositoryProvider)
                  .setArchived(h.id, false),
              child: const Text('Return to the field'),
            ),
          ),
      ],
    );
  }
}

/// Removed habits, kept with their history until the household chooses:
/// Restore puts one back whole; Delete forever is the one hard delete in
/// Furrow, so it is the one that asks first. Nothing is purged on a timer.
/// Renders nothing while nothing is removed.
class _RecentlyRemoved extends ConsumerWidget {
  const _RecentlyRemoved();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final removed = ref.watch(removedHabitsProvider).valueOrNull ?? const [];
    if (removed.isEmpty) return const SizedBox.shrink();
    final repo = ref.read(habitsRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: Text('Recently removed',
              style: Theme.of(context).textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 2, AppSpacing.md, AppSpacing.xs),
          child: Text('Kept with their marks until you delete them.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
        for (final h in removed)
          ListTile(
            leading: Icon(LucideIcons.sprout,
                size: 18, color: Color(h.colorValue)),
            title: Text(h.name),
            subtitle: Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  key: Key('restore-${h.id}'),
                  onPressed: () => repo.restoreHabit(h.id),
                  child: const Text('Restore'),
                ),
                TextButton(
                  key: Key('forever-${h.id}'),
                  onPressed: () async {
                    final ok = await showOhConfirm(
                      context,
                      title: 'Delete ${h.name} forever?',
                      message: 'Its marks go with it. This one cannot be '
                          'undone.',
                      confirmLabel: 'Delete ${h.name} forever',
                      destructive: true,
                    );
                    if (ok) await repo.deleteHabitForever(h.id);
                  },
                  child: const Text('Delete forever'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
