import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:furrow/core/storage/app_database.dart' hide UserPrefs;
import 'package:furrow/features/sanctuary_backup/data/backup_serializer.dart';

/// End-to-end net for Furrow's wiring: the real serializer + real crypto,
/// driven through the package's BackupController with Furrow's actual config
/// (appId 'furrow', appDomain 'furrow', context 'furrow-backup/v1'). The
/// generic controller behaviour (RestoreOutcome mapping, seed flows) is
/// unit-tested in the package itself; this proves Furrow's wiring works
/// against the real sanctuary_auth_core (SANCTUARY-BRIEF §4.W2).
const _validPhrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer makeContainer({
    required AppDatabase database,
    required SecureKeyStore store,
    String? appDomain = 'furrow',
    void Function(Ref ref)? onAfterRestore,
  }) {
    final c = ProviderContainer(overrides: [
      // v0.2.0 takes a MANDATORY pre-restore snapshot; without an in-memory
      // vault the restore path dies as RestoreOutcome.snapshotFailed (no
      // filesystem in tests).
      vaultStoreProvider.overrideWithValue(InMemoryVaultStore()),
      secureKeyStoreProvider.overrideWithValue(store),
      cryptoServiceProvider.overrideWithValue(const DefaultCryptoService()),
      if (appDomain != null)
        sanctuaryAppDomainProvider.overrideWithValue(appDomain),
      backupSerializerProvider
          .overrideWith((ref) => FurrowBackupSerializer(database)),
      sanctuaryBackupConfigProvider.overrideWithValue(
        SanctuaryBackupConfig(
          appId: 'furrow',
          aadContext: 'furrow-backup/v1',
          appDisplayName: 'Furrow',
          onAfterRestore: onAfterRestore,
        ),
      ),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('export → restore round-trips Furrow data through the controller',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.habits).insert(HabitsCompanion.insert(
          id: 'temperance',
          name: 'Temperance',
          cadence: 'binary',
          virtueKey: const Value('temperance'),
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.habitMarks).insert(HabitMarksCompanion.insert(
          id: 'mark-1',
          habitId: 'temperance',
          dateDay: '2026-07-10',
          completed: const Value(true),
          createdAt: now,
          updatedAt: now,
        ));

    final src = makeContainer(
      database: db,
      store:
          InMemorySecureKeyStore(mnemonic: _validPhrase, acknowledged: true),
    );
    final result =
        await src.read(backupControllerProvider.notifier).exportBackup();
    expect(result, isNotNull);
    expect(result!.filename,
        matches(RegExp(r'^furrow-backup-\d{4}-\d{2}-\d{2}\.ohbk$')));
    expect(result.bytes.sublist(0, 4), equals([0x4F, 0x48, 0x42, 0x4B]));

    // Restore into a fresh DB (the six awards already seeded, as they would
    // be on first launch) and a fresh (empty) keychain, by phrase.
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);

    var refreshed = false;
    final dst = makeContainer(
      database: db2,
      store: InMemorySecureKeyStore(),
      onAfterRestore: (_) => refreshed = true,
    );
    final outcome = await dst
        .read(backupControllerProvider.notifier)
        .restoreWithPhrase(result.bytes, _validPhrase);

    expect(outcome, RestoreOutcome.success);
    expect(refreshed, isTrue, reason: 'onAfterRestore must fire');

    final habits = await db2.select(db2.habits).get();
    expect(habits.map((h) => h.id), ['temperance']);

    final marks = await db2.select(db2.habitMarks).get();
    expect(marks, hasLength(1));
  });

  test('a non-OHBK blob restores as corruptFile', () async {
    final c = makeContainer(database: db, store: InMemorySecureKeyStore());
    final outcome = await c
        .read(backupControllerProvider.notifier)
        .restoreWithPhrase(Uint8List.fromList(List.filled(64, 0)), _validPhrase);
    expect(outcome, RestoreOutcome.corruptFile);
  });

  test('a backup encrypted for a different appDomain fails to decrypt',
      () async {
    // Export under appDomain 'furrow' (the container default above)...
    final src = makeContainer(
      database: db,
      store:
          InMemorySecureKeyStore(mnemonic: _validPhrase, acknowledged: true),
    );
    final result =
        await src.read(backupControllerProvider.notifier).exportBackup();

    // ...restoring under no domain (legacy/null) must not silently succeed:
    // the derived key differs, so this is the wrong-phrase path.
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    final c = makeContainer(
      database: db2,
      store: InMemorySecureKeyStore(),
      appDomain: null,
    );

    final outcome = await c
        .read(backupControllerProvider.notifier)
        .restoreWithPhrase(result!.bytes, _validPhrase);

    expect(outcome, RestoreOutcome.wrongPhrase);
  });
}
