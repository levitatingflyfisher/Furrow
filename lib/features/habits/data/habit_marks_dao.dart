// lib/features/habits/data/habit_marks_dao.dart
import 'package:drift/drift.dart';
import 'package:furrow/core/storage/app_database.dart';

part 'habit_marks_dao.g.dart';

@DriftAccessor(tables: [HabitMarks])
class HabitMarksDao extends DatabaseAccessor<AppDatabase>
    with _$HabitMarksDaoMixin {
  HabitMarksDao(super.db);

  /// All marks recorded on a calendar day (for the Today grid). For binary/count
  /// habits there is one row per habit; for duration there may be several.
  Stream<List<HabitMark>> watchForDay(String dateDay) =>
      (select(habitMarks)..where((t) => t.dateDay.equals(dateDay))).watch();

  /// All marks for one habit, newest first (Habit Detail history + heatmap).
  Stream<List<HabitMark>> watchForHabit(String habitId) => (select(habitMarks)
        ..where((t) => t.habitId.equals(habitId))
        ..orderBy([(t) => OrderingTerm.desc(t.dateDay)]))
      .watch();

  /// Every mark (Stats whole-field heatmap).
  Stream<List<HabitMark>> watchAll() => select(habitMarks).watch();

  /// The single binary/count row for a habit on a day, if any.
  Future<HabitMark?> dayMark(String habitId, String dateDay) =>
      (select(habitMarks)
            ..where((t) => t.habitId.equals(habitId) & t.dateDay.equals(dateDay)))
          .getSingleOrNull();

  Future<void> insert(HabitMarksCompanion c) => into(habitMarks).insert(c);

  Future<void> updateValue(String id, int value, bool completed) =>
      (update(habitMarks)..where((t) => t.id.equals(id))).write(
        HabitMarksCompanion(
          value: Value(value),
          completed: Value(completed),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<int> deleteById(String id) =>
      (delete(habitMarks)..where((t) => t.id.equals(id))).go();

  Future<int> deleteForHabit(String habitId) =>
      (delete(habitMarks)..where((t) => t.habitId.equals(habitId))).go();

  /// SUM of duration seconds for a habit on a day (derived duration completion).
  Stream<int> watchSecondsForHabitDay(String habitId, String dateDay) {
    final s = habitMarks.durationSecs.sum();
    return (selectOnly(habitMarks)
          ..addColumns([s])
          ..where(habitMarks.habitId.equals(habitId) &
              habitMarks.dateDay.equals(dateDay)))
        .map((r) => r.read(s) ?? 0)
        .watchSingle();
  }

  /// All-time SUM of duration seconds for a habit (Deep Hours award).
  Stream<int> watchSecondsForHabit(String habitId) {
    final s = habitMarks.durationSecs.sum();
    return (selectOnly(habitMarks)
          ..addColumns([s])
          ..where(habitMarks.habitId.equals(habitId)))
        .map((r) => r.read(s) ?? 0)
        .watchSingle();
  }

  Future<int> secondsForHabit(String habitId) async {
    final s = habitMarks.durationSecs.sum();
    final row = await (selectOnly(habitMarks)
          ..addColumns([s])
          ..where(habitMarks.habitId.equals(habitId)))
        .getSingleOrNull();
    return row?.read(s) ?? 0;
  }

  Future<List<HabitMark>> marksForHabit(String habitId) => (select(habitMarks)
        ..where((t) => t.habitId.equals(habitId))
        ..orderBy([(t) => OrderingTerm.asc(t.dateDay)]))
      .get();

  Future<List<HabitMark>> marksForDay(String dateDay) =>
      (select(habitMarks)..where((t) => t.dateDay.equals(dateDay))).get();
}
