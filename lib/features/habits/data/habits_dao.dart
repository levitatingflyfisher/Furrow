// lib/features/habits/data/habits_dao.dart
import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:furrow/core/storage/app_database.dart';

part 'habits_dao.g.dart';

@DriftAccessor(tables: [Habits])
class HabitsDao extends DatabaseAccessor<AppDatabase> with _$HabitsDaoMixin {
  HabitsDao(super.db);

  /// Active (non-archived) habits, in display order.
  Stream<List<Habit>> watchActive() => (select(habits)
        ..where((t) => t.archived.equals(false) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  /// Resting (archived) habits — the Settings recovery list.
  Stream<List<Habit>> watchArchived() => (select(habits)
        ..where((t) => t.archived.equals(true) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  /// Removed (soft-deleted) habits, most recently removed first — Settings'
  /// Recently removed list.
  Stream<List<Habit>> watchRemoved() => (select(habits)
        ..where((t) => t.deletedAt.isNotNull())
        ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
      .watch();

  /// Every habit that is not removed (active and resting).
  Stream<List<Habit>> watchAll() => (select(habits)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  Stream<Habit?> watchById(String id) =>
      (select(habits)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<Habit?> getById(String id) =>
      (select(habits)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Habit>> getActive() => (select(habits)
        ..where((t) => t.archived.equals(false) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .get();

  /// Every habit, removed ones included (the virtue seed's guard).
  Future<List<Habit>> getAllIncludingRemoved() => select(habits).get();

  Future<void> upsert(HabitsCompanion companion) =>
      into(habits).insertOnConflictUpdate(companion);

  /// Soft delete ([at] = now) or restore ([at] = null).
  Future<void> setDeletedAt(String id, int? at) =>
      (update(habits)..where((t) => t.id.equals(id))).write(
        HabitsCompanion(
          deletedAt: Value(at),
          updatedAt: Value(clock.now().millisecondsSinceEpoch),
        ),
      );

  Future<void> setArchived(String id, bool archived) =>
      (update(habits)..where((t) => t.id.equals(id))).write(
        HabitsCompanion(
          archived: Value(archived),
          updatedAt: Value(clock.now().millisecondsSinceEpoch),
        ),
      );

  Future<int> deleteById(String id) =>
      (delete(habits)..where((t) => t.id.equals(id))).go();

  /// Largest current sortOrder, so a new habit appends to the end.
  Future<int> nextSortOrder() async {
    final maxOrder = habits.sortOrder.max();
    final row = await (selectOnly(habits)..addColumns([maxOrder])).getSingleOrNull();
    return (row?.read(maxOrder) ?? -1) + 1;
  }

  Future<void> reorder(List<String> idsInOrder) async {
    await batch((b) {
      for (var i = 0; i < idsInOrder.length; i++) {
        b.update(
          habits,
          HabitsCompanion(sortOrder: Value(i)),
          where: (t) => t.id.equals(idsInOrder[i]),
        );
      }
    });
  }
}
