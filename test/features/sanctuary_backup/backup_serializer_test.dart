import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:furrow/core/storage/app_database.dart' hide UserPrefs;
import 'package:furrow/features/sanctuary_backup/data/backup_serializer.dart';

void main() {
  late AppDatabase db;
  late FurrowBackupSerializer serializer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    serializer = FurrowBackupSerializer(db);
  });

  tearDown(() => db.close());

  Future<void> seedHabit({
    String id = 'habit-1',
    String name = 'Temperance',
    String cadence = 'binary',
    String? virtueKey = 'temperance',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.habits).insert(
          HabitsCompanion.insert(
            id: id,
            name: name,
            cadence: cadence,
            virtueKey: Value(virtueKey),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> seedMark({
    String id = 'mark-1',
    String habitId = 'habit-1',
    String dateDay = '2026-07-01',
    bool completed = true,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.habitMarks).insert(
          HabitMarksCompanion.insert(
            id: id,
            habitId: habitId,
            dateDay: dateDay,
            value: const Value(1),
            completed: Value(completed),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  group('dumpAll', () {
    test('envelope carries app id and the drift schema version', () async {
      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      expect(json['app'], 'furrow');
      expect(json['schemaVersion'], db.schemaVersion);
      expect(json['tables'], isA<Map<String, dynamic>>());
    });

    test(
        'WIRE-COMPAT: keeps every legacy key AND additively stamps createdAt',
        () async {
      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      // The shipped v1 reader looks at exactly these keys — all must stay,
      // at the top level, so a backup made by THIS build still restores on
      // the old shipped Furrow.
      expect(json['app'], 'furrow');
      expect(json['schemaVersion'], isA<int>());
      expect(json['exportedAt'], isA<String>());
      expect(json['tables'], isA<Map<String, dynamic>>());

      // The v2 retention spec's stamp is ADDED, never replacing exportedAt,
      // and both carry the same instant.
      expect(json['createdAt'], isA<String>());
      expect(json['createdAt'], json['exportedAt']);
      expect(DateTime.parse(json['createdAt'] as String).isUtc, isTrue);
    });

    test('captures habits, marks, badges (seeded), and prefs', () async {
      await seedHabit();
      await seedMark();
      await db.into(db.userPrefs).insert(
            UserPrefsCompanion.insert(key: 'theme', value: 'dark'),
          );

      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final tables = json['tables'] as Map<String, dynamic>;

      expect((tables['habits'] as List).length, 1);
      expect((tables['habitMarks'] as List).length, 1);
      // The six v1 awards are auto-seeded on database creation.
      expect((tables['habitBadges'] as List).length, 6);
      expect((tables['userPrefs'] as List).length, 1);
    });
  });

  group('restoreAll — round trip', () {
    test('restores habits, marks, and prefs verbatim', () async {
      await seedHabit();
      await seedMark(notes: 'felt calm today');
      await db.into(db.userPrefs).insert(
            UserPrefsCompanion.insert(key: 'theme', value: 'dark'),
          );

      final blob = await serializer.dumpAll();

      // Simulate a fresh device: wipe everything, then restore.
      await db.delete(db.habitMarks).go();
      await db.delete(db.habits).go();
      await db.delete(db.userPrefs).go();

      await serializer.restoreAll(blob);

      final habits = await db.select(db.habits).get();
      final marks = await db.select(db.habitMarks).get();
      final prefs = await db.select(db.userPrefs).get();

      expect(habits, hasLength(1));
      expect(habits.single.id, 'habit-1');
      expect(habits.single.virtueKey, 'temperance');
      expect(marks, hasLength(1));
      expect(marks.single.notes, 'felt calm today');
      expect(prefs, hasLength(1));
      expect(prefs.single.value, 'dark');
    });

    test('is destructive-replace: pre-existing rows not in the backup are gone',
        () async {
      await seedHabit(id: 'habit-old', name: 'Old habit');
      final blob = await serializer.dumpAll();

      // A different habit now exists on "this device" that never made it
      // into the backup — restore must wipe it.
      await seedHabit(id: 'habit-new', name: 'New habit');

      await serializer.restoreAll(blob);

      final habits = await db.select(db.habits).get();
      expect(habits.map((h) => h.id), ['habit-old']);
    });

    test('badge catalog is reset then re-applied by id, not deleted', () async {
      // Earn the first-mark award pre-backup.
      await (db.update(db.habitBadges)
            ..where((t) => t.id.equals('first_mark')))
          .write(const HabitBadgesCompanion(earnedAt: Value(1000)));
      final blob = await serializer.dumpAll();

      // Unearn it locally (simulating drift before restore), then restore.
      await (db.update(db.habitBadges)
            ..where((t) => t.id.equals('first_mark')))
          .write(const HabitBadgesCompanion(earnedAt: Value(null)));

      await serializer.restoreAll(blob);

      final badges = await db.select(db.habitBadges).get();
      // Still exactly six catalog rows — never deleted/duplicated.
      expect(badges, hasLength(6));
      final firstMark =
          badges.firstWhere((b) => b.id == 'first_mark');
      expect(firstMark.earnedAt, 1000);
      // Everything else stays unearned.
      expect(
        badges.where((b) => b.id != 'first_mark').every((b) => b.earnedAt == null),
        isTrue,
      );
    });

    test('runs in a single transaction: a bad row aborts with nothing changed',
        () async {
      await seedHabit(id: 'habit-keep', name: 'Kept habit');

      // Hand-craft a payload whose habitMarks entry references a habit id
      // that doesn't exist in its own habits list — insert should fail the
      // FK check inside the transaction, leaving the pre-restore state
      // (the differently-named 'habit-keep' habit) untouched.
      final bad = jsonEncode({
        'app': 'furrow',
        'schemaVersion': db.schemaVersion,
        'tables': {
          'habits': [],
          'habitMarks': [
            {
              'id': 'orphan-mark',
              'habitId': 'no-such-habit',
              'dateDay': '2026-07-01',
              'value': 1,
              'completed': true,
              'createdAt': 1,
              'updatedAt': 1,
            },
          ],
          'habitBadges': [],
          'userPrefs': [],
        },
      });

      await expectLater(
        serializer.restoreAll(Uint8List.fromList(utf8.encode(bad))),
        throwsA(anything),
      );

      final habits = await db.select(db.habits).get();
      expect(habits.map((h) => h.id), ['habit-keep']);
    });
  });

  group('restoreAll — envelope rejection', () {
    test('throws on a payload from a different app', () async {
      final other = jsonEncode({
        'app': 'lullaby',
        'schemaVersion': 1,
        'tables': {
          'habits': [],
          'habitMarks': [],
          'habitBadges': [],
          'userPrefs': [],
        },
      });

      await expectLater(
        serializer.restoreAll(Uint8List.fromList(utf8.encode(other))),
        throwsFormatException,
      );
    });

    test('throws on a missing app field', () async {
      final noApp = jsonEncode({
        'schemaVersion': 1,
        'tables': {
          'habits': [],
          'habitMarks': [],
          'habitBadges': [],
          'userPrefs': [],
        },
      });

      await expectLater(
        serializer.restoreAll(Uint8List.fromList(utf8.encode(noApp))),
        throwsFormatException,
      );
    });

    test('WIRE-COMPAT: a legacy v1 blob (no createdAt, no payload) restores',
        () async {
      // Byte-for-byte the shape the shipped Furrow wrote: app +
      // schemaVersion + exportedAt + top-level tables, and nothing else.
      final now = DateTime.now().millisecondsSinceEpoch;
      final legacy = jsonEncode({
        'app': 'furrow',
        'schemaVersion': db.schemaVersion,
        'exportedAt': '2026-07-01T00:00:00.000Z',
        'tables': {
          'habits': [
            {
              'id': 'legacy-habit',
              'name': 'Silence',
              'cadence': 'binary',
              'createdAt': now,
              'updatedAt': now,
            },
          ],
          'habitMarks': <Object>[],
          'habitBadges': <Object>[],
          'userPrefs': [
            {'key': 'theme', 'value': 'dark'},
          ],
        },
      });

      await serializer.restoreAll(Uint8List.fromList(utf8.encode(legacy)));

      final habits = await db.select(db.habits).get();
      expect(habits.map((h) => h.id), ['legacy-habit']);
      final prefs = await db.select(db.userPrefs).get();
      expect(prefs.single.value, 'dark');
    });

    test('throws BackupSchemaException on a future schema version', () async {
      final future = jsonEncode({
        'app': 'furrow',
        'schemaVersion': db.schemaVersion + 1,
        'tables': {
          'habits': [],
          'habitMarks': [],
          'habitBadges': [],
          'userPrefs': [],
        },
      });

      await expectLater(
        serializer.restoreAll(Uint8List.fromList(utf8.encode(future))),
        throwsA(isA<BackupSchemaException>()),
      );
    });
  });

  group('describeBackup (PreviewableBackupSerializer)', () {
    test('the serializer advertises the preview interface', () {
      expect(serializer, isA<PreviewableBackupSerializer>());
    });

    test('reports table counts and the createdAt stamp without writing',
        () async {
      await seedHabit();
      await seedMark();
      final blob = await serializer.dumpAll();

      // Mutate after the dump; describe must not touch the database.
      await seedHabit(id: 'habit-2', name: 'Order');

      final manifest = await serializer.describeBackup(blob);

      expect(manifest.appId, 'furrow');
      expect(manifest.schemaVersion, db.schemaVersion);
      expect(manifest.createdAt, isNotNull);
      expect(manifest.tableCounts['habits'], 1);
      expect(manifest.tableCounts['habitMarks'], 1);

      final habits = await db.select(db.habits).get();
      expect(habits, hasLength(2), reason: 'describe must never write');
    });

    test('shares restoreAll\'s gate: rejects a different app', () async {
      final other = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'lullaby',
        'schemaVersion': 1,
        'tables': <String, Object>{},
      })));
      await expectLater(
          serializer.describeBackup(other), throwsFormatException);
    });

    test('shares restoreAll\'s gate: rejects a missing tables map', () async {
      final noTables = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'furrow',
        'schemaVersion': db.schemaVersion,
      })));
      await expectLater(
          serializer.describeBackup(noTables), throwsFormatException);
    });

    test('shares restoreAll\'s gate: rejects a future schema', () async {
      final future = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'furrow',
        'schemaVersion': db.schemaVersion + 1,
        'tables': <String, Object>{},
      })));
      await expectLater(serializer.describeBackup(future),
          throwsA(isA<BackupSchemaException>()));
    });
  });
}
