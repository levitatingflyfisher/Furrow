// lib/features/habits/presentation/log_time_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/award_service.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';
import 'package:furrow/shared/extensions/duration_ext.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

/// Opens the duration log sheet for [habit]. One widget shared by the Today
/// grid (tap a duration cell) and the Habit Detail screen, so logging time is
/// always one surface away — never a screen hop.
Future<void> showLogTimeSheet(BuildContext context, Habit habit) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LogTimeSheet(habit: habit),
    );

/// Log time toward a duration habit. Quick-add chips (the prominent, default
/// path) record a known stretch in one tap; a stepper covers an exact amount;
/// a live stopwatch is there too but kept secondary, behind a tap.
class LogTimeSheet extends ConsumerStatefulWidget {
  const LogTimeSheet({super.key, required this.habit});
  final Habit habit;
  @override
  ConsumerState<LogTimeSheet> createState() => _LogTimeSheetState();
}

class _LogTimeSheetState extends ConsumerState<LogTimeSheet> {
  static const _quickMins = [5, 15, 30];
  int _customMins = 10;
  int _todaySecs = 0; // accumulated today, kept live as you log

  // Stopwatch (secondary).
  Timer? _ticker;
  int _elapsed = 0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    final marks = await ref.read(habitsRepositoryProvider).allMarksOnce();
    final key = DateTime.now().toDateDay();
    final secs = marks
        .where((m) => m.habitId == widget.habit.id && m.dateDay == key)
        .fold<int>(0, (s, m) => s + (m.durationSecs ?? 0));
    if (mounted) setState(() => _todaySecs = secs);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _log(int seconds) async {
    if (seconds <= 0) return;
    final now = DateTime.now();
    final repo = ref.read(habitsRepositoryProvider);
    await repo.addDurationSession(
      widget.habit,
      now.toDateDay(),
      startMillis: now.millisecondsSinceEpoch - seconds * 1000,
      endMillis: now.millisecondsSinceEpoch,
      durationSecs: seconds,
    );
    final earned =
        await AwardService(repo, ref.read(awardsDaoProvider)).recheck();
    if (earned.isNotEmpty) {
      ref.read(newlyEarnedAwardsProvider.notifier).state = earned;
    }
    if (mounted) setState(() => _todaySecs += seconds);
  }

  void _toggleTimer() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
    } else {
      _ticker = Timer.periodic(
          const Duration(seconds: 1), (_) => setState(() => _elapsed++));
      setState(() => _running = true);
    }
  }

  Future<void> _logTimer() async {
    _ticker?.cancel();
    final secs = _elapsed;
    setState(() {
      _running = false;
      _elapsed = 0;
    });
    await _log(secs);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Color(widget.habit.colorValue);
    final targetMin = (widget.habit.targetValue / 60).round();
    final todayMin = (_todaySecs / 60).floor();
    final progress = widget.habit.targetValue <= 0
        ? 0.0
        : (_todaySecs / widget.habit.targetValue).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg,
          AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.habit.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text('$todayMin / $targetMin min today',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Quick add — the default, fastest path.
            const _Label('Quick add'),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final m in _quickMins) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: ValueKey('quickadd_$m'),
                      onPressed: () => _log(m * 60),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('+$m min'),
                    ),
                  ),
                  if (m != _quickMins.last) const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Exact amount.
            Row(
              children: [
                Expanded(
                    child: Text('Exact',
                        style: Theme.of(context).textTheme.bodyMedium)),
                IconButton.outlined(
                  onPressed: () => setState(
                      () => _customMins = (_customMins - 5).clamp(5, 600)),
                  icon: const Icon(LucideIcons.minus, size: 18),
                ),
                SizedBox(
                  width: 72,
                  child: Text('$_customMins min',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton.outlined(
                  onPressed: () => setState(
                      () => _customMins = (_customMins + 5).clamp(5, 600)),
                  icon: const Icon(LucideIcons.plus, size: 18),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: () => _log(_customMins * 60),
                  child: const Text('Log'),
                ),
              ],
            ),

            // Stopwatch — secondary, collapsed by default.
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Icon(LucideIcons.timer, size: 18,
                  color: cs.onSurfaceVariant),
              title: Text('Or run a timer',
                  style: Theme.of(context).textTheme.bodyMedium),
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
              children: [
                Text(Duration(seconds: _elapsed).toHhMm(),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(color: color)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _toggleTimer,
                      icon: Icon(
                          _running ? LucideIcons.pause : LucideIcons.play),
                      label: Text(_running ? 'Pause' : 'Start'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: color),
                      onPressed: _elapsed > 0 ? _logTimer : null,
                      icon: const Icon(LucideIcons.check),
                      label: const Text('Log it'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}
