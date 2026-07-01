import 'package:clock/clock.dart';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

import '../../../core/storage/app_database.dart' hide UserPrefs;

/// Serializes all Furrow user data to/from a JSON [Uint8List] for encrypted
/// backup via `sanctuary_backup_ui`.
///
/// Furrow has no pre-existing plaintext export to reuse (there is no
/// export/backup/import code anywhere in `lib/` today) — this is a fresh JSON
/// envelope, following Lullaby's shape (`{app, schemaVersion, exportedAt,
/// tables}`, SANCTUARY-BRIEF §2.8, §4.W2). Works directly off the
/// [AppDatabase] handle the caller passes in — the app's existing
/// `appDatabaseProvider` singleton, never a second connection.
class FurrowBackupSerializer
    implements BackupSerializer, PreviewableBackupSerializer {
  final AppDatabase _db;

  const FurrowBackupSerializer(this._db);

  static const _appId = 'furrow';

  /// Reads every user-data table and returns the JSON payload as bytes.
  ///
  /// The shape is Furrow's SHIPPED one (`app`/`schemaVersion`/`exportedAt`/
  /// top-level `tables`) with one ADDITIVE key the v2 retention spec needs
  /// (`createdAt`, same instant as `exportedAt`). The shipped reader only
  /// looks at app + schemaVersion + tables and ignores unknown keys, so
  /// backups made by this build still restore on pre-v2 Furrow installs —
  /// the wire format is extended, never broken.
  @override
  Future<Uint8List> dumpAll() async {
    final allHabits = await _db.select(_db.habits).get();
    final allMarks = await _db.select(_db.habitMarks).get();
    final allBadges = await _db.select(_db.habitBadges).get();
    final allPrefs = await _db.select(_db.userPrefs).get();

    final stamp = clock.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'app': _appId,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': stamp,
      'createdAt': stamp,
      'tables': {
        'habits': allHabits.map((r) => r.toJson()).toList(),
        'habitMarks': allMarks.map((r) => r.toJson()).toList(),
        'habitBadges': allBadges.map((r) => r.toJson()).toList(),
        'userPrefs': allPrefs.map((r) => r.toJson()).toList(),
      },
    };

    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  /// The dry-run parse behind preview-before-restore and export
  /// verify-by-read-back: validates exactly like [restoreAll] (wrong app,
  /// future schema, missing tables) and reports row counts — never writes.
  @override
  Future<BackupManifest> describeBackup(Uint8List plaintext) async {
    _requireTables(_unwrap(plaintext).payload);
    return BackupEnvelope.describe(plaintext);
  }

  /// The tables gate [restoreAll] applies — shared (the Sundial/Lullaby
  /// pattern) so describe and restore can never drift apart.
  static Map<String, dynamic> _requireTables(Map<String, Object?> payload) {
    final tables = payload['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Missing tables in backup payload');
    }
    return tables;
  }

  /// Envelope validation via the shared fleet helper. Furrow has always
  /// written the `app` key, so it stays required (the default) — a missing
  /// or wrong `app`, a missing `schemaVersion`, or a future schema all
  /// reject exactly as the hand-rolled v1 checks did. Legacy blobs without
  /// `createdAt`/`payload` unwrap fine (stamp falls back to `exportedAt`,
  /// payload to the whole envelope map).
  UnwrappedBackup _unwrap(Uint8List data) => BackupEnvelope.unwrap(
        data,
        expectedAppId: _appId,
        currentSchemaVersion: _db.schemaVersion,
      );

  /// Restores all user data from a JSON [Uint8List] previously created by
  /// [dumpAll].
  ///
  /// **Destructive** — existing Habits/HabitMarks/UserPrefs are wiped before
  /// inserting; HabitBadges (a fixed, code-defined catalog — see below) is
  /// never wiped, only its earned status is reset and re-applied. Runs in a
  /// single transaction: a bad row anywhere aborts the whole restore, leaving
  /// the prior state untouched (SANCTUARY-BRIEF §2.5).
  ///
  /// Throws [FormatException] for a payload from a different app or missing
  /// envelope fields. Throws [BackupSchemaException] when the payload's
  /// schema version is newer than this app understands.
  @override
  Future<void> restoreAll(Uint8List data) async {
    // Defense in depth behind the AEAD context (SANCTUARY-BRIEF §2.8): a
    // decrypted blob from a different app, or a hand-edited/corrupt file, is
    // still rejected here — via the same shared gate describeBackup uses.
    final tables = _requireTables(_unwrap(data).payload);

    await _db.transaction(() async {
      // Clear the (nullable, always-null in the shipped v1 catalog)
      // HabitBadges.habitId FK before wiping Habits, so a future per-habit
      // award type can never turn this into an FK violation (gotcha 3 in
      // scout-Furrow.md).
      await _db
          .update(_db.habitBadges)
          .write(const HabitBadgesCompanion(habitId: Value(null)));

      // Wipe in reverse FK order: HabitMarks (child) before Habits (parent).
      await _db.delete(_db.habitMarks).go();
      await _db.delete(_db.habits).go();
      await _db.delete(_db.userPrefs).go();

      // Insert in FK order: Habits first, then HabitMarks.
      for (final row in _jsonList(tables, 'habits')) {
        await _db.into(_db.habits).insert(
              HabitsCompanion.insert(
                id: row['id'] as String,
                name: row['name'] as String,
                cadence: row['cadence'] as String,
                scheduleType: Value(row['scheduleType'] as String? ?? 'daily'),
                targetValue: Value(row['targetValue'] as int? ?? 1),
                unit: Value(row['unit'] as String?),
                weekdayMask: Value(row['weekdayMask'] as int? ?? 127),
                weeklyTarget: Value(row['weeklyTarget'] as int?),
                icon: Value(row['icon'] as String?),
                colorValue: Value(row['colorValue'] as int? ?? 0xFFB07A2E),
                virtueKey: Value(row['virtueKey'] as String?),
                archived: Value(row['archived'] as bool? ?? false),
                sortOrder: Value(row['sortOrder'] as int? ?? 0),
                createdAt: row['createdAt'] as int,
                updatedAt: row['updatedAt'] as int,
              ),
            );
      }

      for (final row in _jsonList(tables, 'habitMarks')) {
        await _db.into(_db.habitMarks).insert(
              HabitMarksCompanion.insert(
                id: row['id'] as String,
                habitId: row['habitId'] as String,
                dateDay: row['dateDay'] as String,
                value: Value(row['value'] as int? ?? 0),
                completed: Value(row['completed'] as bool? ?? false),
                startTime: Value(row['startTime'] as int?),
                endTime: Value(row['endTime'] as int?),
                durationSecs: Value(row['durationSecs'] as int?),
                notes: Value(row['notes'] as String?),
                createdAt: row['createdAt'] as int,
                updatedAt: row['updatedAt'] as int,
              ),
            );
      }

      // HabitBadges is a fixed, code-defined catalog (`_seedAwards` in
      // AppDatabase), not per-user data — never delete/reinsert it (a
      // backup made on an older app version could have fewer rows than the
      // running app's catalog, silently dropping a newer badge type). Reset
      // every existing catalog row's earned status, then re-apply only what
      // the backup recorded, matched by id; a backup row whose id no longer
      // exists in the running catalog is ignored.
      await _db
          .update(_db.habitBadges)
          .write(const HabitBadgesCompanion(earnedAt: Value(null)));
      for (final row in _jsonList(tables, 'habitBadges')) {
        final earnedAt = row['earnedAt'] as int?;
        if (earnedAt == null) continue;
        await (_db.update(_db.habitBadges)
              ..where((t) => t.id.equals(row['id'] as String)))
            .write(HabitBadgesCompanion(earnedAt: Value(earnedAt)));
      }

      // UserPrefs: a simple key/value store, no FK — delete + reinsert.
      for (final row in _jsonList(tables, 'userPrefs')) {
        await _db.into(_db.userPrefs).insert(
              UserPrefsCompanion.insert(
                key: row['key'] as String,
                value: row['value'] as String,
              ),
            );
      }
    });
  }

  List<Map<String, dynamic>> _jsonList(
    Map<String, dynamic> tables,
    String key,
  ) {
    final list = tables[key] as List<dynamic>?;
    if (list == null) return const [];
    return list.cast<Map<String, dynamic>>();
  }
}
