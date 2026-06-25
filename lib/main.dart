// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/router/app_router.dart';
import 'package:furrow/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FurrowApp(),
    ),
  );
}

class FurrowApp extends ConsumerWidget {
  const FurrowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Furrow',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // On wide screens keep the single-column app centered at a comfortable
      // reading width rather than stretching edge-to-edge (phones pass through).
      builder: (context, child) {
        final inner = child ?? const SizedBox.shrink();
        if (MediaQuery.of(context).size.width <= 760) return inner;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(child: SizedBox(width: 760, child: inner)),
        );
      },
    );
  }
}
