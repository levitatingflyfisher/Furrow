// lib/core/providers/core_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furrow/core/auth/auth_repository.dart';
import 'package:furrow/core/auth/ghost_auth_repository.dart';
import 'package:furrow/core/storage/app_database.dart' hide UserPrefs;
import 'package:furrow/features/habits/data/awards_dao.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/settings/data/local_settings_repository.dart';
import 'package:furrow/features/settings/domain/settings_repository.dart';
import 'package:furrow/features/settings/domain/user_prefs.dart';

part 'core_providers.g.dart';

// Seeded from main() before ProviderScope.
final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

@riverpod
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@riverpod
HabitsRepository habitsRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return HabitsRepository(HabitsDao(db), HabitMarksDao(db));
}

@riverpod
AwardsDao awardsDao(Ref ref) =>
    AwardsDao(ref.watch(appDatabaseProvider));

/// Active (non-archived) habits in display order — the Today grid + Garden.
@riverpod
Stream<List<Habit>> activeHabits(Ref ref) =>
    ref.watch(habitsRepositoryProvider).watchActive();

/// Resting (archived) habits — Settings' way back to the field.
@riverpod
Stream<List<Habit>> restingHabits(Ref ref) =>
    ref.watch(habitsRepositoryProvider).watchArchived();

/// All marks recorded on a given `yyyy-MM-dd` (the Today grid cells).
@riverpod
Stream<List<HabitMark>> marksForDay(Ref ref, String dateDay) =>
    ref.watch(habitsRepositoryProvider).watchMarksForDay(dateDay);

/// All marks for one habit (Habit Detail heatmap + history).
@riverpod
Stream<List<HabitMark>> marksForHabit(Ref ref, String habitId) =>
    ref.watch(habitsRepositoryProvider).watchMarksForHabit(habitId);

/// Every mark (Stats whole-field heatmap + consistency counts).
@riverpod
Stream<List<HabitMark>> allMarks(Ref ref) =>
    ref.watch(habitsRepositoryProvider).watchAllMarks();

/// All awards (earned + unearned) for the badge shelf.
@riverpod
Stream<List<HabitBadge>> awards(Ref ref) =>
    ref.watch(awardsDaoProvider).watchAll();

@riverpod
SettingsRepository settingsRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalSettingsRepository(db);
}

@riverpod
AuthRepository authRepository(Ref ref) => GhostAuthRepository();

@riverpod
Stream<UserPrefs> userPrefs(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchUserPrefs();

@riverpod
ThemeMode themeMode(Ref ref) {
  final prefs = ref.watch(userPrefsProvider);
  return prefs.when(
    data: (p) => p.isDarkMode ? ThemeMode.dark : ThemeMode.light,
    loading: () => ThemeMode.system,
    error: (_, __) => ThemeMode.system,
  );
}

/// Awards earned by the most recent mark write. Set by the habits controller,
/// consumed + cleared by AppShell to trigger the gentle confetti.
final newlyEarnedAwardsProvider =
    StateProvider<List<HabitBadge>>((ref) => const []);
