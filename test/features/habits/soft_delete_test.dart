import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/sanctuary_backup/data/backup_serializer.dart';

/// Removing a habit is deliberate, so it does not ask first (fleet delete
/// ruling): it soft-deletes, the Undo bar offers it straight back, and
/// Settings keeps a lasting Recently removed list with Restore and a
/// confirmed Delete forever. These pin the storage half of that contract.
void main() {
  late AppDatabase db;
  late HabitsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
  });
  tearDown(() => db.close());

  Future<String> plantWithMark() async {
    final id = await repo.createHabit(name: 'Read', cadence: Cadence.binary);
    await repo.setBinary((await repo.getHabit(id))!, '2026-07-01', true);
    return id;
  }

  test('remove hides the habit everywhere but keeps its marks', () async {
    final id = await plantWithMark();
    await repo.removeHabit(id);

    expect(await repo.watchActive().first, isEmpty);
    expect(await repo.watchArchived().first, isEmpty);
    expect(await repo.activeHabitsOnce(), isEmpty);
    expect((await repo.watchRemoved().first).map((h) => h.id), [id]);
    expect(await repo.watchMarksForHabit(id).first, hasLength(1));
  });

  test('a resting habit that is removed leaves the Resting list', () async {
    final id = await plantWithMark();
    await repo.setArchived(id, true);
    await repo.removeHabit(id);
    expect(await repo.watchArchived().first, isEmpty);
    expect(await repo.watchRemoved().first, hasLength(1));
  });

  test('restore brings the habit and its history back', () async {
    final id = await plantWithMark();
    await repo.removeHabit(id);
    await repo.restoreHabit(id);

    expect((await repo.watchActive().first).map((h) => h.id), [id]);
    expect(await repo.watchRemoved().first, isEmpty);
    expect(await repo.watchMarksForHabit(id).first, hasLength(1));
  });

  test('delete forever is the one hard delete: habit and marks go', () async {
    final id = await plantWithMark();
    await repo.removeHabit(id);
    await repo.deleteHabitForever(id);

    expect(await repo.getHabit(id), isNull);
    expect(await repo.watchRemoved().first, isEmpty);
    expect(await repo.allMarksOnce(), isEmpty);
  });

  group('backup', () {
    test('a removed habit round-trips as removed', () async {
      final id = await plantWithMark();
      await repo.removeHabit(id);
      final ser = FurrowBackupSerializer(db);
      final bytes = await ser.dumpAll();
      await repo.restoreHabit(id);
      await ser.restoreAll(bytes);
      expect((await repo.watchRemoved().first).map((h) => h.id), [id]);
      expect(await repo.watchActive().first, isEmpty);
    });

    test('a v1 backup (no deletedAt key) restores every habit as live',
        () async {
      final ser = FurrowBackupSerializer(db);
      final v1 = jsonEncode({
        'app': 'furrow',
        'schemaVersion': 1,
        'exportedAt': '2026-07-01T00:00:00Z',
        'tables': {
          'habits': [
            {
              'id': 'h1',
              'name': 'Walk',
              'cadence': 'binary',
              'createdAt': 1,
              'updatedAt': 1,
            }
          ],
          'habitMarks': [],
          'habitBadges': [],
          'userPrefs': [],
        },
      });
      await ser.restoreAll(utf8.encode(v1));
      expect((await repo.watchActive().first).map((h) => h.id), ['h1']);
    });
  });

  test('migration v1 -> v2 keeps existing habits and adds deletedAt', () async {
    final dir = Directory(
        '${Directory.systemTemp.path}/furrow_mig_${DateTime.now().microsecondsSinceEpoch}');
    await dir.create(recursive: true);
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v1.sqlite');

    // The shipped v1 schema, verbatim from sqlite_master of a v1 database.
    final v1 = NativeDatabase(file, setup: (raw) {
      raw.execute('CREATE TABLE "habits" ("id" TEXT NOT NULL, "name" TEXT '
          'NOT NULL, "cadence" TEXT NOT NULL, "schedule_type" TEXT NOT NULL '
          "DEFAULT 'daily', \"target_value\" INTEGER NOT NULL DEFAULT 1, "
          '"unit" TEXT NULL, "weekday_mask" INTEGER NOT NULL DEFAULT 127, '
          '"weekly_target" INTEGER NULL, "icon" TEXT NULL, "color_value" '
          'INTEGER NOT NULL DEFAULT 4289755694, "virtue_key" TEXT NULL, '
          '"archived" INTEGER NOT NULL DEFAULT 0 CHECK ("archived" IN (0, 1)), '
          '"sort_order" INTEGER NOT NULL DEFAULT 0, "created_at" INTEGER NOT '
          'NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))');
      raw.execute('CREATE TABLE "habit_marks" ("id" TEXT NOT NULL, '
          '"habit_id" TEXT NOT NULL REFERENCES habits (id), "date_day" TEXT '
          'NOT NULL, "value" INTEGER NOT NULL DEFAULT 0, "completed" INTEGER '
          'NOT NULL DEFAULT 0 CHECK ("completed" IN (0, 1)), "start_time" '
          'INTEGER NULL, "end_time" INTEGER NULL, "duration_secs" INTEGER '
          'NULL, "notes" TEXT NULL, "created_at" INTEGER NOT NULL, '
          '"updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))');
      raw.execute('CREATE TABLE "habit_badges" ("id" TEXT NOT NULL, "kind" '
          'TEXT NOT NULL, "threshold" INTEGER NOT NULL DEFAULT 0, "habit_id" '
          'TEXT NULL REFERENCES habits (id), "earned_at" INTEGER NULL, '
          'PRIMARY KEY ("id"))');
      raw.execute('CREATE TABLE "user_prefs" ("key" TEXT NOT NULL, "value" '
          'TEXT NOT NULL, PRIMARY KEY ("key"))');
      raw.execute("INSERT INTO habits (id, name, cadence, created_at, "
          "updated_at) VALUES ('old', 'Walk', 'binary', 1, 1)");
      raw.execute('PRAGMA user_version = 1');
    });
    // Force the setup to run, then close.
    await v1.ensureOpen(_NoopUser());
    await v1.close();

    final migrated = AppDatabase(NativeDatabase(file));
    addTearDown(migrated.close);
    final r = HabitsRepository(HabitsDao(migrated), HabitMarksDao(migrated));
    final live = await r.watchActive().first;
    expect(live.map((h) => h.id), ['old']);
    expect(live.single.deletedAt, isNull);
    await r.removeHabit('old');
    expect(await r.watchActive().first, isEmpty);
  });
}

class _NoopUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
