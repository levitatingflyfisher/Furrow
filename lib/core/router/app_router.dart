// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/router/app_shell.dart';
import 'package:furrow/features/habits/presentation/garden_screen.dart';
import 'package:furrow/features/habits/presentation/habit_detail_screen.dart';
import 'package:furrow/features/habits/presentation/habit_edit_sheet.dart';
import 'package:furrow/features/habits/presentation/today_screen.dart';
import 'package:furrow/features/onboarding/presentation/onboarding_screen.dart';
import 'package:furrow/features/settings/presentation/settings_screen.dart';
import 'package:furrow/features/stats/presentation/stats_screen.dart';

part 'app_router.g.dart';

CustomTransitionPage<T> _fade<T>({required LocalKey key, required Widget child}) =>
    CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, a, __, c) =>
          FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: c),
    );

CustomTransitionPage<T> _slideUp<T>(
        {required LocalKey key, required Widget child}) =>
    CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (_, a, __, c) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: c,
      ),
    );

@riverpod
GoRouter appRouter(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return GoRouter(
    initialLocation: '/today',
    redirect: (context, state) async {
      if (state.matchedLocation == '/onboarding') return null;
      final prefs = await db.select(db.userPrefs).get();
      if (prefs.isEmpty) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (c, s) =>
            _fade(key: s.pageKey, child: const OnboardingScreen()),
      ),
      ShellRoute(
        builder: (c, s, child) => AppShell(child: child),
        routes: [
          GoRoute(
              path: '/today',
              pageBuilder: (c, s) =>
                  _fade(key: s.pageKey, child: const TodayScreen())),
          GoRoute(
              path: '/garden',
              pageBuilder: (c, s) =>
                  _fade(key: s.pageKey, child: const GardenScreen())),
          GoRoute(
              path: '/stats',
              pageBuilder: (c, s) =>
                  _fade(key: s.pageKey, child: const StatsScreen())),
          GoRoute(
              path: '/settings',
              pageBuilder: (c, s) =>
                  _fade(key: s.pageKey, child: const SettingsScreen())),
        ],
      ),
      GoRoute(
        path: '/habit/new',
        pageBuilder: (c, s) =>
            _slideUp(key: s.pageKey, child: const HabitEditSheet()),
      ),
      GoRoute(
        path: '/habit/:id',
        pageBuilder: (c, s) => _slideUp(
            key: s.pageKey,
            child: HabitDetailScreen(habitId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/habit/:id/edit',
        pageBuilder: (c, s) => _slideUp(
            key: s.pageKey,
            child: HabitEditSheet(habitId: s.pathParameters['id']!)),
      ),
    ],
  );
}
