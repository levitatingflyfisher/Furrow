// lib/core/router/app_shell.dart
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/habits/domain/awards.dart';
import 'package:furrow/shared/theme/app_colors.dart';

/// Owns the app chrome: the Today/Garden/Stats/Settings shell with its four-tab
/// nav bar. The gentle confetti + quiet fact line fire when an award is earned.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(newlyEarnedAwardsProvider, (_, awards) {
      if (awards.isEmpty) return;
      _confetti.play();
      // Every award the write earned, by name with its quiet line, and it
      // stays until dismissed (audit finding 4: a four-second snackbar
      // showing awards.first only was missed by a phone in a pocket).
      final lines = [
        for (final a in awards)
          if (kAwardById[a.id] case final meta?)
            'Earned ${meta.name}: ${meta.fact}'
          else
            'A mark made.',
      ];
      // Banners queue: a reveal still on screen is never swept away unread
      // by the next one.
      final messenger = ScaffoldMessenger.of(context);
      messenger.showMaterialBanner(
        MaterialBanner(
          leading: const Icon(LucideIcons.sprout),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final l in lines)
                Text(l, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const Text('OK'),
            ),
          ],
        ),
      );
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          ref.read(newlyEarnedAwardsProvider.notifier).state = const [];
        }
      });
    });

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Positioned.fill gives the Scaffold TIGHT constraints. As a bare
        // (non-positioned) Stack child it would get loose ones and collapse the
        // body to zero height, so the Today grid's lazy ListView built nothing.
        Positioned.fill(child: _shell(context)),
        // Gentle confetti: few particles, slow drift, furrow/gold/linen only.
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          numberOfParticles: 14,
          maxBlastForce: 9,
          minBlastForce: 4,
          emissionFrequency: 0.04,
          gravity: 0.12,
          minimumSize: const Size(6, 6),
          maximumSize: const Size(11, 11),
          colors: const [
            AppColors.furrow500,
            AppColors.furrow700,
            AppColors.sunGold,
            AppColors.linen200,
          ],
        ),
      ],
    );
  }

  AppBar _bar() {
    final themeMode =
        ref.watch(userPrefsProvider).valueOrNull?.themeMode ??
        OhThemeModePreference.defaultValue;
    return AppBar(
      title: const Text('Furrow'),
      centerTitle: false,
      actions: [
        // "Plant a habit" lives in the bar, not a floating button: an extended
        // FAB floated over the bottom grid rows and intercepted taps meant for
        // their day-cells (e.g. logging time on a lower habit).
        // Icon plus a short word (fleet top-bar ruling), not an icon whose
        // only name is a tooltip a phone cannot show.
        TextButton.icon(
          icon: const Icon(LucideIcons.plus),
          label: const Text('Plant'),
          onPressed: () => context.push('/habit/new'),
        ),
        // The one theme control (light / dark / follow phone), on every
        // tab's bar so it is never more than two taps away.
        OhThemeToggle(
          value: themeMode,
          onChanged: (m) =>
              ref.read(settingsRepositoryProvider).setThemeMode(m),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _shell(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = switch (location) {
      '/garden' => 1,
      '/stats' => 2,
      '/settings' => 3,
      _ => 0,
    };
    return Scaffold(
      appBar: _bar(),
      // Capped and centred on tablets and wide browser windows; the tabs'
      // own lists keep their padding, so phones render as before.
      body: OhPage(padding: EdgeInsets.zero, child: widget.child),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Undo for a removed habit, above the tabs. The shell outlives
          // every tab, and the removal is soft, so nothing commits here.
          // The nav bar below owns the bottom inset; without this the
          // bar's own SafeArea would add an empty gesture-bar band above it.
          MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: OhUndoBar(
              controller: ref.watch(habitUndoProvider),
              commitOnDispose: false,
            ),
          ),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(
              const ['/today', '/garden', '/stats', '/settings'][i],
            ),
            destinations: const [
              NavigationDestination(
                icon: Icon(LucideIcons.layoutGrid),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.sprout),
                label: 'Garden',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.barChart2),
                label: 'Stats',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
