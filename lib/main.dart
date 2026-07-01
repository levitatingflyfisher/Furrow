// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/router/app_router.dart';
import 'package:furrow/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:furrow/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Encrypted-backup wiring (sanctuary_backup_ui). Furrow is a new app
        // to this feature, so it gets its own isolated key material
        // (appDomain 'furrow') and its own AEAD context — no legacy-compat
        // constraint like Lullaby's (SANCTUARY-BRIEF §2.1, §2.3, §4.W2).
        sanctuaryAppDomainProvider.overrideWithValue('furrow'),
        sanctuaryBackupConfigProvider.overrideWithValue(
          SanctuaryBackupConfig(
            appId: 'furrow',
            aadContext: 'furrow-backup/v1',
            appDisplayName: 'Furrow',
            restoreReplaceConsequence:
                'Restoring will delete all current habits, marks, and '
                'earned awards on this device, then replace them with data '
                'from the backup file.',
            // The Today/Garden/Stats screens watch Drift streams
            // (activeHabits, marksForDay, marksForHabit, allMarks, awards)
            // that self-refresh on the underlying table write — the restore
            // runs through this same appDatabaseProvider singleton, never a
            // second handle. userPrefs (and the themeMode that derives from
            // it) is invalidated explicitly since a restore can bring back a
            // different theme/week-start preference from the backup.
            onAfterRestore: (ref) {
              ref.invalidate(activeHabitsProvider);
              ref.invalidate(marksForDayProvider);
              ref.invalidate(marksForHabitProvider);
              ref.invalidate(allMarksProvider);
              ref.invalidate(awardsProvider);
              ref.invalidate(userPrefsProvider);
            },
          ),
        ),
        backupSerializerProvider.overrideWith(
          (ref) => FurrowBackupSerializer(ref.watch(appDatabaseProvider)),
        ),
      ],
      child: const FurrowApp(),
    ),
  );
}

class FurrowApp extends ConsumerStatefulWidget {
  const FurrowApp({super.key});

  @override
  ConsumerState<FurrowApp> createState() => _FurrowAppState();
}

class _FurrowAppState extends ConsumerState<FurrowApp> {
  @override
  void initState() {
    super.initState();
    // Silent freshness snapshot (BACKUP_RETENTION_SPEC §3): if a key exists
    // and the newest vault snapshot is stale, take one. Post-first-frame +
    // fire-and-forget — never blocks boot, never surfaces errors (the same
    // hook Sundial and Lullaby run at startup).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backupControllerProvider.notifier).runStartupMaintenance();
    });
  }

  @override
  Widget build(BuildContext context) {
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
