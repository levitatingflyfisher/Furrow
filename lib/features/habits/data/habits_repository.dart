// lib/features/habits/data/habits_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/features/habits/domain/franklin_virtues.dart';

/// CRUD for habits + the per-cadence marking logic. Binary/count keep one row
/// per (habit, day) via app-logic upsert; duration appends a session row.
class HabitsRepository {
  HabitsRepository(this._habits, this._marks);
  final HabitsDao _habits;
  final HabitMarksDao _marks;
  static const _uuid = Uuid();

  // ── Habits ────────────────────────────────────────────────────────────────
  Stream<List<Habit>> watchActive() => _habits.watchActive();
  Stream<List<Habit>> watchAll() => _habits.watchAll();
  Future<List<Habit>> activeHabitsOnce() => _habits.getActive();
  Future<List<HabitMark>> allMarksOnce() => _marks.getAll();
  Stream<Habit?> watchHabit(String id) => _habits.watchById(id);
  Future<Habit?> getHabit(String id) => _habits.getById(id);
  Future<void> reorder(List<String> ids) => _habits.reorder(ids);
  Future<void> setArchived(String id, bool v) => _habits.setArchived(id, v);

  Future<String> createHabit({
    required String name,
    required Cadence cadence,
    int targetValue = 1,
    String? unit,
    ScheduleType scheduleType = ScheduleType.daily,
    int weekdayMask = kDailyMask,
    String? icon,
    int colorValue = 0xFFB07A2E,
    String? virtueKey,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final order = await _habits.nextSortOrder();
    await _habits.upsert(HabitsCompanion.insert(
      id: id,
      name: name,
      cadence: cadence.name,
      scheduleType: Value(scheduleType.name),
      targetValue: Value(targetValue),
      unit: Value(unit),
      weekdayMask: Value(weekdayMask),
      icon: Value(icon),
      colorValue: Value(colorValue),
      virtueKey: Value(virtueKey),
      sortOrder: Value(order),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  Future<void> updateHabit(
    Habit h, {
    String? name,
    int? targetValue,
    String? unit,
    ScheduleType? scheduleType,
    int? weekdayMask,
    String? icon,
    int? colorValue,
  }) async {
    await _habits.upsert(HabitsCompanion(
      id: Value(h.id),
      name: Value(name ?? h.name),
      cadence: Value(h.cadence),
      scheduleType: Value(scheduleType?.name ?? h.scheduleType),
      targetValue: Value(targetValue ?? h.targetValue),
      unit: Value(unit ?? h.unit),
      weekdayMask: Value(weekdayMask ?? h.weekdayMask),
      icon: Value(icon ?? h.icon),
      colorValue: Value(colorValue ?? h.colorValue),
      virtueKey: Value(h.virtueKey),
      archived: Value(h.archived),
      sortOrder: Value(h.sortOrder),
      createdAt: Value(h.createdAt),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Deletes a habit and all its marks.
  Future<void> deleteHabit(String id) async {
    await _marks.deleteForHabit(id);
    await _habits.deleteById(id);
  }

  /// Seeds Franklin's thirteen virtues as binary/daily habits (idempotent on
  /// virtueKey — skips any already present).
  Future<void> seedFranklinVirtues() async {
    final existing = await _habits.getActive();
    final present = existing.map((h) => h.virtueKey).whereType<String>().toSet();
    var order = await _habits.nextSortOrder();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final v in kFranklinVirtues) {
      if (present.contains(v.key)) continue;
      await _habits.upsert(HabitsCompanion.insert(
        id: _uuid.v4(),
        name: v.name,
        cadence: Cadence.binary.name,
        virtueKey: Value(v.key),
        sortOrder: Value(order++),
        createdAt: now,
        updatedAt: now,
      ));
    }
  }

  // ── Marks ─────────────────────────────────────────────────────────────────
  Stream<List<HabitMark>> watchMarksForDay(String dateDay) =>
      _marks.watchForDay(dateDay);
  Stream<List<HabitMark>> watchMarksForHabit(String habitId) =>
      _marks.watchForHabit(habitId);
  Stream<List<HabitMark>> watchAllMarks() => _marks.watchAll();
  Stream<int> watchSecondsForHabitDay(String habitId, String dateDay) =>
      _marks.watchSecondsForHabitDay(habitId, dateDay);

  /// Binary: set done/undone for the day (one row upserted).
  Future<void> setBinary(Habit h, String dateDay, bool done) async {
    final existing = await _marks.dayMark(h.id, dateDay);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing == null) {
      await _marks.insert(HabitMarksCompanion.insert(
        id: _uuid.v4(),
        habitId: h.id,
        dateDay: dateDay,
        value: Value(done ? 1 : 0),
        completed: Value(done),
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      await _marks.updateValue(existing.id, done ? 1 : 0, done);
    }
  }

  /// Count: change the day's running value by [delta], clamped to [0, ∞).
  /// Returns the new value. Completion is value >= target.
  Future<int> adjustCount(Habit h, String dateDay, int delta) async {
    final existing = await _marks.dayMark(h.id, dateDay);
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = existing?.value ?? 0;
    final next = (current + delta).clamp(0, 1 << 30);
    final done = next >= h.targetValue;
    if (existing == null) {
      await _marks.insert(HabitMarksCompanion.insert(
        id: _uuid.v4(),
        habitId: h.id,
        dateDay: dateDay,
        value: Value(next),
        completed: Value(done),
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      await _marks.updateValue(existing.id, next, done);
    }
    return next;
  }

  /// Duration: append a logged session (many-per-day). Day completion is
  /// derived from the SUM of the day's sessions, not this row.
  Future<void> addDurationSession(
    Habit h,
    String dateDay, {
    required int startMillis,
    required int endMillis,
    required int durationSecs,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _marks.insert(HabitMarksCompanion.insert(
      id: _uuid.v4(),
      habitId: h.id,
      dateDay: dateDay,
      value: Value(durationSecs),
      completed: const Value(false), // derived per-day
      startTime: Value(startMillis),
      endTime: Value(endMillis),
      durationSecs: Value(durationSecs),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> deleteMark(String id) => _marks.deleteById(id);
}
