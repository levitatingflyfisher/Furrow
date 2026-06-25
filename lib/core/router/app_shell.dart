// lib/core/router/app_shell.dart
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/habits/domain/awards.dart';
import 'package:furrow/features/habits/presentation/today_screen.dart';
import 'package:furrow/features/settings/domain/user_prefs.dart';
import 'package:furrow/shared/theme/app_colors.dart';
import 'package:furrow/shared/widgets/mode_pill.dart';
import 'package:furrow/shared/widgets/theme_pill.dart';

/// Owns the app chrome. Flow mode (default) shows only the Today grid for a
/// calm single surface; Rich mode adds a four-tab nav. The gentle confetti +
/// quiet fact line fire when an award is earned.
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
      final fact = kAwardById[awards.first.id]?.fact ?? 'A mark made.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(fact, style: Theme.of(context).textTheme.titleMedium),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          ref.read(newlyEarnedAwardsProvider.notifier).state = const [];
        }
      });
    });

    final widgetOverride = ref.watch(widgetLaunchOverrideProvider);
    final mode = widgetOverride
        ? AppMode.flow
        : (ref.watch(appModeProvider).valueOrNull ?? AppMode.flow);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        mode == AppMode.flow ? _flow(context) : _rich(context),
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

  AppBar _bar() => AppBar(
        title: const Text('Furrow'),
        centerTitle: false,
        actions: const [
          Padding(padding: EdgeInsets.only(right: 8), child: ThemePill()),
        ],
      );

  Widget _fab() => FloatingActionButton.extended(
        onPressed: () => context.push('/habit/new'),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Habit'),
      );

  Widget _flow(BuildContext context) => Scaffold(
        appBar: _bar(),
        body: const TodayScreen(),
        floatingActionButton: _fab(),
        bottomNavigationBar: const SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: ModePill()),
          ),
        ),
      );

  Widget _rich(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = switch (location) {
      '/garden' => 1,
      '/stats' => 2,
      '/settings' => 3,
      _ => 0,
    };
    return Scaffold(
      appBar: _bar(),
      body: widget.child,
      floatingActionButton: index == 0 ? _fab() : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: ModePill(),
          ),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(
                const ['/today', '/garden', '/stats', '/settings'][i]),
            destinations: const [
              NavigationDestination(
                  icon: Icon(LucideIcons.layoutGrid), label: 'Today'),
              NavigationDestination(
                  icon: Icon(LucideIcons.sprout), label: 'Garden'),
              NavigationDestination(
                  icon: Icon(LucideIcons.barChart2), label: 'Stats'),
              NavigationDestination(
                  icon: Icon(LucideIcons.settings), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }
}
