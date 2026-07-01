import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/main.dart';

/// The silent app-open freshness net (BACKUP_RETENTION_SPEC §3): booting
/// [FurrowApp] with a key set up and an empty (therefore stale) vault must
/// take one snapshot, post-first-frame — without any user action.
const _validPhrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

void main() {
  testWidgets('FurrowApp boot takes a freshness snapshot when vault is stale',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final vault = InMemoryVaultStore();

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      vaultStoreProvider.overrideWithValue(vault),
      secureKeyStoreProvider.overrideWithValue(
        InMemorySecureKeyStore(mnemonic: _validPhrase, acknowledged: true),
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

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const FurrowApp(),
    ));
    // Let the post-frame hook fire and the (fake-crypto) export finish.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final entries = await vault.list();
    expect(entries, hasLength(1),
        reason: 'boot with a key and an empty vault must snapshot silently');
  });

  testWidgets('FurrowApp boot takes no snapshot without a key',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final vault = InMemoryVaultStore();

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      vaultStoreProvider.overrideWithValue(vault),
      secureKeyStoreProvider.overrideWithValue(InMemorySecureKeyStore()),
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

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const FurrowApp(),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(await vault.list(), isEmpty,
        reason: 'freshness is a kindness for set-up users, never a ghost-'
            'tier surprise');
  });
}
