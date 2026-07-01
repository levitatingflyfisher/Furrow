import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:furrow/features/sanctuary_backup/presentation/backup_section.dart';

/// F6-class regression guard for Furrow's native-tile BackupSection.
///
/// The 320dp/3.0x sweep in backup_section_test.dart (and the fleet-wide
/// equivalents in every other app) only ever pumps the CLOSED tile list —
/// none of them tap into the restore-confirm or reset-identity AlertDialogs
/// that carry the longest, app-customized copy. This file opens both
/// dialogs under the worst-case narrow/large-text combo.
///
/// A realistic phone height (480, not the closed-sweep's 1400) at 3.0 scale
/// is what actually stresses a fixed-height dialog vertically — verified by
/// running both tests against the pre-refactor `showConfirmDialog` (no
/// `scrollable: true`), where they go red, then against the current
/// `BackupFlow`-delegated dialogs (`scrollable: true`), where they're green.
const _validPhrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

/// A fake [FilePicker] that always "picks" the given in-memory blob, so the
/// restore-confirm dialog can be reached without a real OS file dialog.
///
/// Since v0.2.0 the flow decrypts FIRST (preview-before-restore), so the
/// picked bytes must be a genuinely decryptable .ohbk blob — a garbage blob
/// now short-circuits to a corruptFile snackbar before any dialog opens.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.blob);

  final Uint8List blob;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return FilePickerResult([
      PlatformFile(
        name: 'furrow-backup-2026-07-12.ohbk',
        size: blob.length,
        bytes: blob,
      ),
    ]);
  }
}

List<Override> _overrides(SecureKeyStore store) => [
      // v0.2.0's mandatory pre-restore snapshot needs a working vault store;
      // in tests that's the in-memory fake, never the filesystem.
      vaultStoreProvider.overrideWithValue(InMemoryVaultStore()),
      secureKeyStoreProvider.overrideWithValue(store),
      cryptoServiceProvider
          .overrideWithValue(FakeCryptoService(mnemonic: _validPhrase)),
      sanctuaryAppDomainProvider.overrideWithValue('furrow'),
      sanctuaryBackupConfigProvider.overrideWithValue(
        const SanctuaryBackupConfig(
          appId: 'furrow',
          aadContext: 'furrow-backup/v1',
          appDisplayName: 'Furrow',
          restoreReplaceConsequence:
              'Restoring will permanently delete every virtue, streak, '
              'FurrowRow entry, and award currently on this device, then '
              'replace them with the contents of the backup file.',
        ),
      ),
      backupSerializerProvider.overrideWithValue(FakeBackupSerializer()),
    ];

/// Exports a real, decryptable .ohbk blob through the same overrides the
/// widget test uses (same FakeCryptoService keys, same appDomain/context),
/// so the fake file picker can hand the flow something it can actually open.
Future<Uint8List> _exportRealBlob() async {
  final container = ProviderContainer(
    overrides: _overrides(
      InMemorySecureKeyStore(mnemonic: _validPhrase, acknowledged: true),
    ),
  );
  addTearDown(container.dispose);
  final result =
      await container.read(backupControllerProvider.notifier).exportBackup();
  return result!.bytes;
}

Widget _wrap(Widget child, {required SecureKeyStore store}) {
  return ProviderScope(
    overrides: _overrides(store),
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(3.0)),
        child: child!,
      ),
      home: Scaffold(body: ListView(children: [child])),
    ),
  );
}

void main() {
  setUp(() async => FilePicker.platform = _FakeFilePicker(await _exportRealBlob()));

  group('BackupSection opened-dialog overflow (320dp x 3.0 text scale)', () {
    testWidgets('Restore confirm dialog does not overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        const BackupSection(),
        store: InMemorySecureKeyStore(
            mnemonic: _validPhrase, acknowledged: true),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.ensureVisible(find.text('Restore from backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();

      // The destructive-restore confirmation actually rendered...
      expect(find.text('Replace all data?'), findsOneWidget);
      // ...and its long, app-customized consequence sentence fits without a
      // vertical overflow at 320dp / 3.0x text scale.
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reset identity confirm dialog does not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        const BackupSection(),
        store: InMemorySecureKeyStore(
            mnemonic: _validPhrase, acknowledged: true),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.ensureVisible(find.text('Reset identity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset identity'));
      await tester.pumpAndSettle();

      expect(find.text('Reset identity?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
