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
AppDatabase appDatabase(AppDatabaseRef ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@riverpod
HabitsRepository habitsRepository(HabitsRepositoryRef ref) {
  final db = ref.watch(appDatabaseProvider);
  return HabitsRepository(HabitsDao(db), HabitMarksDao(db));
}

@riverpod
AwardsDao awardsDao(AwardsDaoRef ref) =>
    AwardsDao(ref.watch(appDatabaseProvider));

/// Active (non-archived) habits in display order — the Today grid + Garden.
@riverpod
Stream<List<Habit>> activeHabits(ActiveHabitsRef ref) =>
    ref.watch(habitsRepositoryProvider).watchActive();

/// All marks recorded on a given `yyyy-MM-dd` (the Today grid cells).
@riverpod
Stream<List<HabitMark>> marksForDay(MarksForDayRef ref, String dateDay) =>
    ref.watch(habitsRepositoryProvider).watchMarksForDay(dateDay);

/// All marks for one habit (Habit Detail heatmap + history).
@riverpod
Stream<List<HabitMark>> marksForHabit(MarksForHabitRef ref, String habitId) =>
    ref.watch(habitsRepositoryProvider).watchMarksForHabit(habitId);

/// Every mark (Stats whole-field heatmap + consistency counts).
@riverpod
Stream<List<HabitMark>> allMarks(AllMarksRef ref) =>
    ref.watch(habitsRepositoryProvider).watchAllMarks();

/// All awards (earned + unearned) for the badge shelf.
@riverpod
Stream<List<HabitBadge>> awards(AwardsRef ref) =>
    ref.watch(awardsDaoProvider).watchAll();

@riverpod
SettingsRepository settingsRepository(SettingsRepositoryRef ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalSettingsRepository(db);
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) => GhostAuthRepository();

@riverpod
Stream<AppMode> appMode(AppModeRef ref) =>
    ref.watch(settingsRepositoryProvider).watchAppMode();

@riverpod
Stream<UserPrefs> userPrefs(UserPrefsRef ref) =>
    ref.watch(settingsRepositoryProvider).watchUserPrefs();

@riverpod
ThemeMode themeMode(ThemeModeRef ref) {
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

/// Transient flag: when true, AppShell forces Flow mode regardless of the
/// durable [AppMode] preference (set via the widget launch MethodChannel path).
final widgetLaunchOverrideProvider = StateProvider<bool>((ref) => false);

class _WidgetLaunchLifecycleObserver with WidgetsBindingObserver {
  _WidgetLaunchLifecycleObserver(this._ref);
  final Ref _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _ref.read(widgetLaunchOverrideProvider.notifier).state = false;
    }
  }
}

final widgetLaunchLifecycleObserverProvider = Provider<WidgetsBindingObserver>(
  (ref) {
    final observer = _WidgetLaunchLifecycleObserver(ref);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
    return observer;
  },
);
