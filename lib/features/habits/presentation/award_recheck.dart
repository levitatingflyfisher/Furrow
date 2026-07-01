import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/habits/data/award_service.dart';

/// The one place award rechecks happen after a mark write. Today, the time
/// sheet, and the evening review all log through this instead of each
/// carrying its own copy (the third write surface was the cue to extract).
Future<void> recheckAwards(WidgetRef ref) async {
  final earned = await AwardService(
    ref.read(habitsRepositoryProvider),
    ref.read(awardsDaoProvider),
  ).recheck();
  if (earned.isNotEmpty) {
    ref.read(newlyEarnedAwardsProvider.notifier).state = earned;
  }
}
