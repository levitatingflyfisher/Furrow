// lib/features/habits/data/habits_repository.dart
import 'package:clock/clock.dart';
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
  Stream<List<Habit>> watchArchived() => _habits.watchArchived();
  Stream<List<Habit>> watchAll() => _habits.watchAll();
  Stream<List<Habit>> watchRemoved() => _habits.watchRemoved();
  Future<List<Habit>> activeHabitsOnce() => _habits.getActive();
  Future<List<HabitMark>> allMarksOnce() => _marks.getAll();
  Stream<Habit?> watchHabit(String id) => _habits.watchById(id);
  Future<Habit?> getHabit(String id) => _habits.getById(id);
  Future<void> reorder(List<String> ids) => _habits.reorder(ids);
  /// Rests or wakes a habit by hand. A Franklin virtue still waiting for its
  /// week leaves the rotation's care here: what the household chose stands.
  Future<void> setArchived(String id, bool v) async {
    final h = await _habits.getById(id);
    final key = h?.virtueKey;
    if (key != null) {
      final waiting = await _waitingVirtues();
      if (waiting.remove(key)) await _setWaitingVirtues(waiting);
    }
    await _habits.setArchived(id, v);
  }

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
    final now = clock.now().millisecondsSinceEpoch;
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
      updatedAt: Value(clock.now().millisecondsSinceEpoch),
    ));
  }

  /// Removes a habit softly: it leaves every list but keeps its marks, and
  /// [restoreHabit] brings it back whole (the Undo bar, then Settings'
  /// Recently removed list).
  Future<void> removeHabit(String id) =>
      _habits.setDeletedAt(id, clock.now().millisecondsSinceEpoch);

  Future<void> restoreHabit(String id) => _habits.setDeletedAt(id, null);

  /// Deletes a habit and all its marks for good: the one hard delete, only
  /// reachable from Recently removed behind a confirm.
  Future<void> deleteHabitForever(String id) async {
    await _marks.deleteForHabit(id);
    await _habits.deleteById(id);
  }

  /// Seeds Franklin's thirteen virtues as binary/daily habits, idempotent on
  /// virtueKey across every habit the household has: an active or resting
  /// virtue is left as it is, and a removed one is brought back rather than
  /// planted a second time. Returns what it did.
  ///
  /// Franklin worked one virtue a week (checklist-manifesto-01): a newly
  /// planted [focusKey] (this week's virtue) starts active, and every other
  /// newly planted virtue starts resting, waiting for its week. The weekly
  /// rotation wakes each in turn ([promoteFocusVirtue]).
  Future<SeedResult> seedFranklinVirtues({required String focusKey}) async {
    final existing = await _habits.getAllIncludingRemoved();
    final byKey = <String, Habit>{};
    for (final h in existing) {
      final k = h.virtueKey;
      if (k != null) byKey.putIfAbsent(k, () => h);
    }
    var order = await _habits.nextSortOrder();
    final now = clock.now().millisecondsSinceEpoch;
    final waiting = await _waitingVirtues();
    var planted = 0, restored = 0, resting = 0, active = 0;
    var focusPlanted = false;
    for (final v in kFranklinVirtues) {
      final h = byKey[v.key];
      if (h == null) {
        final isFocus = v.key == focusKey;
        await _habits.upsert(HabitsCompanion.insert(
          id: _uuid.v4(),
          name: v.name,
          cadence: Cadence.binary.name,
          virtueKey: Value(v.key),
          archived: Value(!isFocus),
          sortOrder: Value(order++),
          createdAt: now,
          updatedAt: now,
        ));
        if (isFocus) {
          focusPlanted = true;
        } else {
          waiting.add(v.key);
        }
        planted++;
      } else if (h.deletedAt != null) {
        await restoreHabit(h.id);
        restored++;
      } else if (h.archived) {
        resting++;
      } else {
        active++;
      }
    }
    await _setWaitingVirtues(waiting);
    final focusName =
        kFranklinVirtues.where((v) => v.key == focusKey).firstOrNull?.name;
    return SeedResult(
      planted: planted,
      restored: restored,
      resting: resting,
      alreadyActive: active,
      waiting: planted - (focusPlanted ? 1 : 0),
      focusName: focusPlanted ? focusName : null,
    );
  }

  /// The weekly rotation: wakes [focusKey]'s virtue if the seed left it
  /// waiting for its week. Last week's virtue stays awake (nothing earned is
  /// taken away). A virtue rested or woken by hand, or removed, is left
  /// alone. Returns whether it woke one.
  Future<bool> promoteFocusVirtue(String focusKey) async {
    final waiting = await _waitingVirtues();
    if (!waiting.contains(focusKey)) return false;
    final rows = await _habits.getAllIncludingRemoved();
    final h = rows.where((h) => h.virtueKey == focusKey).firstOrNull;
    waiting.remove(focusKey);
    await _setWaitingVirtues(waiting);
    if (h == null || h.deletedAt != null || !h.archived) return false;
    await _habits.setArchived(h.id, false);
    return true;
  }

  /// Virtue keys the seed planted resting and the rotation has not woken.
  static const _kWaiting = 'franklin_waiting';

  Future<Set<String>> _waitingVirtues() async {
    final db = _habits.attachedDatabase;
    final row = await (db.select(db.userPrefs)
          ..where((p) => p.key.equals(_kWaiting)))
        .getSingleOrNull();
    final v = row?.value ?? '';
    return {for (final k in v.split(',')) if (k.isNotEmpty) k};
  }

  Future<void> _setWaitingVirtues(Set<String> keys) {
    final db = _habits.attachedDatabase;
    return db.into(db.userPrefs).insertOnConflictUpdate(
        UserPrefsCompanion.insert(key: _kWaiting, value: keys.join(',')));
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
    // Serialize the read-modify-write so two quick taps can't both insert a
    // fresh row for the same (habit, day) — see adjustCount.
    await _marks.transaction(() async {
      final existing = await _marks.dayMark(h.id, dateDay);
      final now = clock.now().millisecondsSinceEpoch;
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
    });
  }

  /// Count: change the day's running value by [delta], clamped to [0, ∞).
  /// Returns the new value. Completion is value >= target.
  Future<int> adjustCount(Habit h, String dateDay, int delta) async {
    // Serialize the read-modify-write: two rapid taps fire concurrently
    // (fire-and-forget onTap), and without a transaction both read "no row yet"
    // and insert, duplicating (habitId, dateDay) — after which dayMark throws
    // and the cell's writes silently die. A transaction makes the second tap
    // wait and see the first's row.
    return _marks.transaction(() async {
      final existing = await _marks.dayMark(h.id, dateDay);
      final now = clock.now().millisecondsSinceEpoch;
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
    });
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
    final now = clock.now().millisecondsSinceEpoch;
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

  /// Puts deleted marks back (the detail screen's Undo). A binary/count day
  /// keeps one row, so a mark whose day has been re-marked since is skipped
  /// rather than duplicated; duration sessions always go back.
  Future<void> restoreMarks(Habit h, List<HabitMark> marks) =>
      _marks.transaction(() async {
        final oneRowPerDay = Cadence.fromName(h.cadence) != Cadence.duration;
        for (final m in marks) {
          if (oneRowPerDay && await _marks.dayMark(h.id, m.dateDay) != null) {
            continue;
          }
          await _marks.insertRow(m);
        }
      });

  /// Clear a habit's whole history, keeping the habit. The "reset" the
  /// detail screen offers — forgiveness over prevention applies to data
  /// too: a fresh start should never require deleting and re-planting.
  Future<void> clearMarks(String habitId) => _marks.deleteForHabit(habitId);
}
