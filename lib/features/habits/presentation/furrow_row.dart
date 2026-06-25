// lib/features/habits/presentation/furrow_row.dart
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';
import 'package:furrow/shared/theme/app_colors.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

/// One habit as a row in the Today grid: a cadence glyph, the habit name, and a
/// seven-day strip of inked cells. Completing today's cell blooms the ink. A
/// filled week reads as a furrow cut clean. This is Furrow's signature surface.
class FurrowRow extends StatelessWidget {
  const FurrowRow({
    super.key,
    required this.habit,
    required this.weekDays,
    required this.marks,
    required this.today,
    required this.onTapToday,
    required this.onLongPressToday,
    this.onOpen,
  });

  final Habit habit;
  final List<DateTime> weekDays; // Mon..Sun
  final List<HabitMark> marks; // this habit's marks (any range)
  final DateTime today;
  final VoidCallback onTapToday;
  final VoidCallback onLongPressToday;
  final VoidCallback? onOpen;

  IconData get _glyph => switch (Cadence.fromName(habit.cadence)) {
        Cadence.binary => LucideIcons.check,
        Cadence.count => LucideIcons.plus,
        Cadence.duration => LucideIcons.timer,
      };

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.colorValue);
    final todayKey = today.toDateDay();

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm + 2, horizontal: AppSpacing.sm),
        child: Row(
          children: [
            Icon(_glyph, size: 18, color: color.withValues(alpha: 0.85)),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Seven-day strip.
            for (final day in weekDays)
              _DayCell(
                key: day.toDateDay() == todayKey
                    ? ValueKey('today_${habit.id}')
                    : null,
                color: color,
                progress: dayProgress(habit, marks, day),
                isToday: day.toDateDay() == todayKey,
                isFuture: day.isAfter(today),
                scheduled: isScheduledOn(habit, day),
                onTap: day.toDateDay() == todayKey ? onTapToday : null,
                onLongPress:
                    day.toDateDay() == todayKey ? onLongPressToday : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.color,
    required this.progress,
    required this.isToday,
    required this.isFuture,
    required this.scheduled,
    this.onTap,
    this.onLongPress,
  });

  final Color color;
  final double progress; // 0..1 toward the day's target
  final bool isToday;
  final bool isFuture;
  final bool scheduled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final emptyOutline = (dark ? AppColors.linen200 : AppColors.linen900)
        .withValues(alpha: isToday ? 0.45 : 0.16);
    final fillColor = color.withValues(alpha: isFuture ? 0.25 : 1.0);
    final filled = progress >= 1.0;
    // Any nonzero progress shows a visible sliver rising from the bottom, so a
    // single +1 or logged minute registers immediately instead of staying
    // blank until the whole target lands.
    final fillFactor = filled
        ? 1.0
        : (progress <= 0 ? 0.0 : progress.clamp(0.18, 0.92));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 26,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        child: SizedBox(
          width: 20,
          height: 20,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: filled ? fillColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: filled
                  ? null
                  : Border.all(
                      color: scheduled
                          ? emptyOutline
                          : emptyOutline.withValues(alpha: 0.5),
                      width: isToday ? 1.6 : 1.0,
                    ),
            ),
            child: filled
                ? null
                // The furrow filling: a partial bloom from the bottom up.
                : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        widthFactor: 1,
                        heightFactor: fillFactor,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: fillColor),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
