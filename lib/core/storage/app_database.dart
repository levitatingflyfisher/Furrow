// lib/core/storage/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

/// A habit the household is cultivating. Three cadences share one table:
/// `binary` (a daily tick), `count` (reach N per day), `duration` (log time).
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get cadence => text()(); // 'binary' | 'count' | 'duration'
  TextColumn get scheduleType =>
      text().withDefault(const Constant('daily'))(); // 'daily'|'specificDays'|'weeklyCount'
  IntColumn get targetValue => integer().withDefault(const Constant(1))();
  // binary=1; count=N (e.g. 8 glasses); duration=SECONDS (1800 = 30 min)
  TextColumn get unit => text().nullable()(); // count label: 'glasses','pages'
  IntColumn get weekdayMask =>
      integer().withDefault(const Constant(127))(); // Mon=bit0..Sun=bit6; daily=127
  IntColumn get weeklyTarget => integer().nullable()(); // weeklyCount (deferred UI)
  TextColumn get icon => text().nullable()(); // icon key
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFFB07A2E))(); // furrow500
  TextColumn get virtueKey => text().nullable()(); // 'temperance'… null for user habits
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One mark against a habit. Surrogate id PK so duration habits can record many
/// sessions per day; binary/count are upserted in app-logic keyed on
/// (habitId, dateDay). `completed` is a snapshot for binary/count and derived
/// (SUM(durationSecs) >= target) for duration.
class HabitMarks extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();
  TextColumn get dateDay => text()(); // 'yyyy-MM-dd' LOCAL
  IntColumn get value => integer().withDefault(const Constant(0))();
  // binary=0|1; count=running n; duration=seconds for this session
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  // duration-only session columns (nullable):
  IntColumn get startTime => integer().nullable()();
  IntColumn get endTime => integer().nullable()();
  IntColumn get durationSecs => integer().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Earned-once awards. `earnedAt` null = unearned; once set it is permanent
/// (never revoked). `habitId` null = a global award.
class HabitBadges extends Table {
  TextColumn get id => text()(); // 'first_mark','chain_7'…
  TextColumn get kind => text()(); // BadgeKind name
  IntColumn get threshold => integer().withDefault(const Constant(0))();
  TextColumn get habitId => text().nullable().references(Habits, #id)();
  IntColumn get earnedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple key→value store for preferences (theme, mode, virtue-seed flag, etc.).
class UserPrefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Habits, HabitMarks, HabitBadges, UserPrefs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'furrow',
              // Web needs to know where the sqlite3 WASM engine + drift worker
              // live (both shipped in web/); without this drift_flutter throws
              // "the `web` parameter needs to be set" at startup.
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedAwards();
          await customStatement(
              'CREATE INDEX IF NOT EXISTS ix_marks_habit_day ON habit_marks(habit_id, date_day)');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// The six v1 awards, seeded unearned. Checks are hardcoded (no general
  /// criterion engine in v1); see AwardService.
  Future<void> _seedAwards() async {
    const seeds = <(String, String, int)>[
      ('first_mark', 'firstMark', 0),
      ('chain_7', 'chainDays', 7),
      ('chain_30', 'chainDays', 30),
      ('clean_week', 'cleanWeek', 0),
      ('count_target_7', 'countTarget', 7),
      ('duration_25h', 'durationTotal', 90000), // 25h in seconds
    ];
    for (final (id, kind, threshold) in seeds) {
      await into(habitBadges).insert(
        HabitBadgesCompanion.insert(
          id: id,
          kind: kind,
          threshold: Value(threshold),
        ),
      );
    }
  }
}
