import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/settings/presentation/settings_screen.dart';

/// Regression guard for the fleet a11y convention (SANCTUARY-BRIEF §4.W2):
/// the settings screen, now including the encrypted-backup section, must not
/// overflow at the worst-case narrow-width / large-accessibility-text combo.
Future<ProviderContainer> _makeContainer() async {
  final db = AppDatabase(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    sharedPreferencesProvider.overrideWithValue(prefs),
    secureKeyStoreProvider.overrideWithValue(
      InMemorySecureKeyStore(
        mnemonic: 'abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon about',
        acknowledged: true,
        lastBackupAt: DateTime(2026, 7, 1),
      ),
    ),
    cryptoServiceProvider.overrideWithValue(FakeCryptoService()),
    sanctuaryAppDomainProvider.overrideWithValue('furrow'),
    sanctuaryBackupConfigProvider.overrideWithValue(
      const SanctuaryBackupConfig(
        appId: 'furrow',
        aadContext: 'furrow-backup/v1',
        appDisplayName: 'Furrow',
      ),
    ),
    backupSerializerProvider.overrideWithValue(FakeBackupSerializer()),
  ]);
  addTearDown(container.dispose);
  addTearDown(db.close);
  return container;
}

void main() {
  testWidgets('settings screen does not overflow at 320dp / textScale 3.0',
      (tester) async {
    final container = await _makeContainer();

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 800);

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(3.0)),
        child: child!,
      ),
      home: UncontrolledProviderScope(
        container: container,
        child: const Scaffold(body: SettingsScreen()),
      ),
    ));
    // Give the auth notifier time to derive keys so the "seed acknowledged"
    // (Export/Reset-identity) branch of BackupSection renders too.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);

    // Scroll the backup section into view — ListView only builds items
    // within the viewport/cache extent, so this also exercises the widget's
    // own layout at 320dp/textScale 3.0, not just the tiles above the fold.
    await tester.scrollUntilVisible(
      find.text('Encrypted Backup'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Encrypted Backup'), findsOneWidget);
    expect(find.text('Export backup'), findsOneWidget);

    // The v0.2.0 tiles must also survive the 320dp/3.0x sweep. Scroll each
    // into the built viewport (ListView laziness) before asserting.
    await tester.scrollUntilVisible(
      find.text('Previous backups'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Previous backups'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Export as plain JSON'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Export as plain JSON'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Reset identity'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Reset identity'), findsOneWidget);
  });

  testWidgets('renders the backup section between the divider and the info tile',
      (tester) async {
    final container = await _makeContainer();

    await tester.pumpWidget(MaterialApp(
      home: UncontrolledProviderScope(
        container: container,
        child: const Scaffold(body: SettingsScreen()),
      ),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Encrypted Backup'), findsOneWidget);
    expect(find.text('Furrow'), findsOneWidget); // the info tile still there
  });
}
