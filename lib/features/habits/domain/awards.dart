// lib/features/habits/domain/awards.dart
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Display metadata for the six v1 awards. The earn-state lives in the
/// HabitBadges table; this is the calm, non-shouty presentation layer. `fact`
/// is the quiet line shown with the gentle confetti (no "Achievement Unlocked").
class AwardMeta {
  final String id;
  final String name;
  final String description;
  final String fact;
  final IconData icon;
  const AwardMeta(this.id, this.name, this.description, this.fact, this.icon);
}

const List<AwardMeta> kAwardMeta = [
  AwardMeta('first_mark', 'First Light', 'Your first completed mark.',
      'First mark.', LucideIcons.sprout),
  AwardMeta('chain_7', 'Seven', 'A seven-day chain on any one habit.',
      'Seven days.', LucideIcons.link),
  AwardMeta('chain_30', 'Whetted', 'A thirty-day chain — the groove is worn.',
      'Thirty days. The groove holds.', LucideIcons.gem),
  AwardMeta('clean_week', 'Clean Week',
      'Every habit met on every scheduled day of one week.', 'A clean week.',
      LucideIcons.calendarCheck),
  AwardMeta('count_target_7', 'Full Measure',
      'A counted habit at full target, seven days running.',
      'Full measure, seven days.', LucideIcons.target),
  AwardMeta('duration_25h', 'Deep Hours',
      'Twenty-five hours logged on one habit.', 'Twenty-five hours deep.',
      LucideIcons.hourglass),
];

final Map<String, AwardMeta> kAwardById = {
  for (final a in kAwardMeta) a.id: a,
};
