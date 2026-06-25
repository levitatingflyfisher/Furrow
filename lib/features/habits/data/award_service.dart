// lib/features/habits/data/award_service.dart
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/awards_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/domain/habit_logic.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';

/// Evaluates the six v1 awards with hardcoded checks (no general criterion
/// engine) and earns — permanently — any newly met. Returns the awards earned
/// by this call so the shell can play the gentle confetti.
class AwardService {
  AwardService(this._repo, this._awards);
  final HabitsRepository _repo;
  final AwardsDao _awards;

  Future<List<HabitBadge>> recheck() async {
    final unearned =
        (await _awards.getAll()).where((a) => a.earnedAt == null).toList();
    if (unearned.isEmpty) return const [];

    final habits = await _repo.activeHabitsOnce();
    final marks = await _repo.allMarksOnce();
    List<HabitMark> marksOf(Habit h) =>
        marks.where((m) => m.habitId == h.id).toList();
    final today = DateTime.now();

    final newly = <HabitBadge>[];
    for (final a in unearned) {
      if (_met(a, habits, marksOf, today)) {
        await _awards.earn(a.id, DateTime.now().millisecondsSinceEpoch);
        newly.add(a);
      }
    }
    return newly;
  }

  bool _met(HabitBadge a, List<Habit> habits,
      List<HabitMark> Function(Habit) marksOf, DateTime today) {
    switch (a.id) {
      case 'first_mark':
        return habits.any((h) => completedDayKeys(h, marksOf(h)).isNotEmpty);
      case 'chain_7':
        return habits.any((h) => bestStreak(h, marksOf(h)) >= 7);
      case 'chain_30':
        return habits.any((h) => bestStreak(h, marksOf(h)) >= 30);
      case 'count_target_7':
        return habits.any((h) =>
            Cadence.fromName(h.cadence) == Cadence.count &&
            bestStreak(h, marksOf(h)) >= 7);
      case 'duration_25h':
        return habits.any((h) =>
            Cadence.fromName(h.cadence) == Cadence.duration &&
            marksOf(h).fold<int>(0, (s, m) => s + (m.durationSecs ?? 0)) >=
                a.threshold);
      case 'clean_week':
        return _cleanWeek(habits, marksOf, today);
      default:
        return false;
    }
  }

  /// A past calendar week (Mon..Sun, fully elapsed) in which every active habit
  /// was completed on every day it was scheduled. Scans the last 8 weeks.
  bool _cleanWeek(List<Habit> habits,
      List<HabitMark> Function(Habit) marksOf, DateTime today) {
    if (habits.isEmpty) return false;
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    for (var w = 1; w <= 8; w++) {
      final monday = thisMonday.subtract(Duration(days: 7 * w));
      final weekEnd = monday.add(const Duration(days: 6));
      var allMet = true;
      var anyScheduled = false;
      for (final h in habits) {
        // Skip a habit that didn't exist for the whole week.
        if (DateTime.fromMillisecondsSinceEpoch(h.createdAt).isAfter(monday)) {
          allMet = false;
          break;
        }
        final done = completedDayKeys(h, marksOf(h));
        for (var d = 0; d < 7; d++) {
          final day = monday.add(Duration(days: d));
          if (day.isAfter(weekEnd)) break;
          if (!isScheduledOn(h, day)) continue;
          anyScheduled = true;
          if (!done.contains(day.toDateDay())) {
            allMet = false;
            break;
          }
        }
        if (!allMet) break;
      }
      if (allMet && anyScheduled) return true;
    }
    return false;
  }
}
