import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';

/// The Today grid fires taps as fire-and-forget onTap handlers, so two quick
/// taps run adjustCount/setBinary concurrently. Both awaited the day's mark,
/// both saw "no row yet", and both inserted a fresh row — duplicating
/// (habitId, dateDay). dayMark then throws (getSingleOrNull with >1 row), so
/// every later write on that cell silently dies. These tests reproduce the race
/// and lock in the serialized read-modify-write.
void main() {
  late AppDatabase db;
  late HabitsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
  });
  tearDown(() => db.close());

  Future<List<HabitMark>> marksFor(String habitId, String day) =>
      (db.select(db.habitMarks)
            ..where((m) => m.habitId.equals(habitId))
            ..where((m) => m.dateDay.equals(day)))
          .get();

  test('two concurrent count taps keep one mark and lose no increment',
      () async {
    final id = await repo.createHabit(
      name: 'Water',
      cadence: Cadence.count,
      targetValue: 8,
    );
    final habit = (await repo.getHabit(id))!;

    await Future.wait([
      repo.adjustCount(habit, '2026-07-01', 1),
      repo.adjustCount(habit, '2026-07-01', 1),
    ]);

    final marks = await marksFor(habit.id, '2026-07-01');
    expect(marks.length, 1,
        reason: 'concurrent taps must not duplicate the (habit,day) row');
    expect(marks.single.value, 2, reason: 'both increments must be recorded');
  });

  test('two concurrent binary taps keep a single mark', () async {
    final id = await repo.createHabit(
      name: 'Floss',
      cadence: Cadence.binary,
    );
    final habit = (await repo.getHabit(id))!;

    await Future.wait([
      repo.setBinary(habit, '2026-07-01', true),
      repo.setBinary(habit, '2026-07-01', true),
    ]);

    final marks = await marksFor(habit.id, '2026-07-01');
    expect(marks.length, 1);
    expect(marks.single.completed, isTrue);
  });
}
