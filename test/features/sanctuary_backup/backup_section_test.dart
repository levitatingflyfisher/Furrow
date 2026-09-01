import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:furrow/features/sanctuary_backup/presentation/backup_section.dart';

/// Furrow's own Lucide-icon presentation of the encrypted-backup flow
/// (SANCTUARY-BRIEF §4.W2 — dropping in the package's generic Material-icon
/// `BackupSettingsSection` would clash with Furrow's Lucide convention
/// elsewhere on this screen, same choice Sundial's report documents).
Widget _wrap(Widget child, {required SecureKeyStore store}) {
  return ProviderScope(
    overrides: [
      // The vault sheet (and any restore path) needs a vault store that
      // works without a filesystem.
      vaultStoreProvider.overrideWithValue(InMemoryVaultStore()),
      secureKeyStoreProvider.overrideWithValue(store),
      // Deterministic + fast — skips real PBKDF2 so tests don't need a
      // multi-second pumpAndSettle to let key derivation finish.
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
    ],
    child: MaterialApp(home: Scaffold(body: ListView(children: [child]))),
  );
}

void main() {
  group('BackupSection', () {
    testWidgets('shows "Set up encrypted backup" in ghost state',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupSection(), store: InMemorySecureKeyStore()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set up encrypted backup'), findsOneWidget);
      expect(find.text('Export backup'), findsNothing);
    });

    testWidgets('shows "Restore from backup" always', (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupSection(), store: InMemorySecureKeyStore()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restore from backup'), findsOneWidget);
    });

    testWidgets('shows Export, Show words and Remove recovery words after setup',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BackupSection(),
          store: InMemorySecureKeyStore(
            mnemonic: 'abandon abandon abandon abandon abandon abandon '
                'abandon abandon abandon abandon abandon about',
            acknowledged: true,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Export backup'), findsOneWidget);
      expect(find.text('Set up encrypted backup'), findsNothing);
      expect(find.text('Remove recovery words'), findsOneWidget);
      expect(find.text('Show my recovery words'), findsOneWidget);
    });

    testWidgets('shows the "Previous backups" vault tile always',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupSection(), store: InMemorySecureKeyStore()),
      );
      await tester.pumpAndSettle();

      // Always available: restores and exports populate the vault
      // regardless of auth state (same as the package section).
      expect(find.text('Previous backups'), findsOneWidget);
    });

    testWidgets('tapping "Previous backups" opens the vault sheet',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupSection(), store: InMemorySecureKeyStore()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Previous backups'));
      await tester.pumpAndSettle();

      // The sheet's empty-vault copy proves showBackupVaultSheet ran.
      expect(find.textContaining('No snapshots'), findsOneWidget);
    });

    testWidgets('shows the plain-JSON export tile always', (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupSection(), store: InMemorySecureKeyStore()),
      );
      await tester.pumpAndSettle();

      // Needs no key: sovereignty means you can READ your data.
      expect(find.text('Export as plain JSON'), findsOneWidget);
      expect(find.text('Unencrypted: readable by any program'),
          findsOneWidget);
    });

    testWidgets('tapping the plain-JSON tile opens the honesty confirm',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupSection(), store: InMemorySecureKeyStore()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export as plain JSON'));
      await tester.pumpAndSettle();

      expect(find.text('Export unencrypted copy?'), findsOneWidget);
    });

    testWidgets('shows section header', (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupSection(), store: InMemorySecureKeyStore()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backup'), findsOneWidget);
    });

    // The heading is drawn with its content in every state, never over
    // nothing (backup package 0.3.0 migration note).
    testWidgets('while backup status loads: heading plus a status line',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupSection(), store: _SlowStore()),
      );
      await tester.pump();
      expect(find.text('Backup'), findsOneWidget);
      expect(find.text('Checking backup status…'), findsOneWidget);
    });

    testWidgets('if backup status cannot be read: heading, why, Try again',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupSection(), store: _BrokenStore()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Backup'), findsOneWidget);
      expect(find.textContaining('Couldn’t read your backup settings'),
          findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('restore names the file plainly, not by extension',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupSection(), store: InMemorySecureKeyStore()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Load data from a backup file'), findsOneWidget);
      expect(find.textContaining('.ohbk'), findsNothing);
    });
  });
}

/// Never answers, so the auth state stays loading.
class _SlowStore extends InMemorySecureKeyStore {
  @override
  Future<String?> readMnemonic() => Completer<String?>().future;
}

/// Fails to read, so the auth state is an error.
class _BrokenStore extends InMemorySecureKeyStore {
  @override
  Future<String?> readMnemonic() async => throw StateError('keychain locked');
}
