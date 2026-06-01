// lib/features/onboarding/presentation/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/settings/domain/user_prefs.dart';
import 'package:furrow/shared/theme/app_colors.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  Future<void> _finish(_Template t) async {
    final repo = ref.read(habitsRepositoryProvider);
    switch (t) {
      case _Template.three:
        await repo.createHabit(
            name: 'Move', cadence: Cadence.binary, colorValue: 0xFF5E9478);
        await repo.createHabit(
            name: 'Read',
            cadence: Cadence.duration,
            targetValue: 20 * 60,
            colorValue: 0xFFB07A2E);
        await repo.createHabit(
            name: 'Water',
            cadence: Cadence.count,
            targetValue: 8,
            unit: 'glasses',
            colorValue: 0xFF5C7599);
      case _Template.franklin:
        await repo.seedFranklinVirtues();
      case _Template.blank:
        break;
    }
    // Writing any pref row marks the app as onboarded (router redirect checks
    // for an empty UserPrefs table).
    await ref.read(settingsRepositoryProvider).setAppMode(AppMode.flow);
    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _page,
          onPageChanged: (i) => setState(() => _index = i),
          children: [
            _Welcome(onNext: () => _page.nextPage(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut)),
            _TemplatePage(onChoose: _finish),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 2; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.furrow500
                        : AppColors.furrow500.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onNext});
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomPaint(
              size: const Size(120, 84), painter: _InkedGridPainter()),
          const SizedBox(height: AppSpacing.xl),
          Text('Furrow', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Text('We are what we repeatedly do.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A quiet daily grid for the habits and virtues you mean to keep. '
            'Each day you tend, the line is cut a little deeper. Nothing leaves '
            'your device.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(LucideIcons.arrowRight, size: 18),
              label: const Text('Begin'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Template { three, franklin, blank }

class _TemplatePage extends StatelessWidget {
  const _TemplatePage({required this.onChoose});
  final void Function(_Template) onChoose;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Where to begin?',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        _Choice(
          icon: LucideIcons.sprout,
          title: 'Start with three',
          subtitle: 'Move, Read, Water — a tick, a timer, and a count.',
          recommended: true,
          onTap: () => onChoose(_Template.three),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Choice(
          icon: LucideIcons.bookOpen,
          title: "Franklin's thirteen virtues",
          subtitle: 'Temperance, Silence, Order… his book of days.',
          onTap: () => onChoose(_Template.franklin),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Choice(
          icon: LucideIcons.square,
          title: 'A blank field',
          subtitle: 'Plant your own from scratch.',
          onTap: () => onChoose(_Template.blank),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.recommended = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool recommended;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: recommended ? cs.primary : cs.outlineVariant,
            width: recommended ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (recommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('suggested',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.primary)),
                      ),
                    ],
                  ]),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small inked grid — the welcome mark (replaces Sundial's gnomon face).
class _InkedGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cols = 7, rows = 3;
    final cw = size.width / cols, ch = size.height / rows;
    final filled = {0, 1, 2, 3, 7, 8, 9, 14, 15}; // a furrow cut clean-ish
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(c * cw + 2, r * ch + 2, cw - 6, ch - 6),
          const Radius.circular(4),
        );
        final paint = Paint()
          ..color = filled.contains(i)
              ? AppColors.furrow500
              : AppColors.furrow500.withValues(alpha: 0.18)
          ..style = filled.contains(i) ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
