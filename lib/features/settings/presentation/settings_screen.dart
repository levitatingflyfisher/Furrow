// lib/features/settings/presentation/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/sanctuary_backup/presentation/backup_section.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark =
        ref.watch(userPrefsProvider).valueOrNull?.isDarkMode ?? false;
    final settings = ref.read(settingsRepositoryProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        SwitchListTile(
          secondary: const Icon(LucideIcons.moon),
          title: const Text('Dark'),
          value: isDark,
          onChanged: settings.setDarkMode,
        ),
        ListTile(
          leading: const Icon(LucideIcons.bookOpen),
          title: const Text("Plant Franklin's thirteen virtues"),
          subtitle: const Text('Adds them as daily habits'),
          onTap: () async {
            await ref.read(habitsRepositoryProvider).seedFranklinVirtues();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('The thirteen virtues are planted.'),
                behavior: SnackBarBehavior.floating,
              ));
            }
          },
        ),
        const _RestingHabits(),
        const BackupSection(),
        const Divider(),
        const ListTile(
          leading: Icon(LucideIcons.info),
          title: Text('Furrow'),
          subtitle: Text(
              'We are what we repeatedly do.\nLocal-first — no ads, no account, no cloud.'),
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
