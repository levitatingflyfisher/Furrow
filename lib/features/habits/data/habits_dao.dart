// lib/features/habits/data/habits_dao.dart
import 'package:drift/drift.dart';
import 'package:furrow/core/storage/app_database.dart';

part 'habits_dao.g.dart';

@DriftAccessor(tables: [Habits])
class HabitsDao extends DatabaseAccessor<AppDatabase> with _$HabitsDaoMixin {
  HabitsDao(super.db);

  /// Active (non-archived) habits, in display order.
  Stream<List<Habit>> watchActive() => (select(habits)
        ..where((t) => t.archived.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  Stream<List<Habit>> watchAll() => (select(habits)
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  Stream<Habit?> watchById(String id) =>
      (select(habits)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<Habit?> getById(String id) =>
      (select(habits)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Habit>> getActive() => (select(habits)
        ..where((t) => t.archived.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .get();

  Future<void> upsert(HabitsCompanion companion) =>
      into(habits).insertOnConflictUpdate(companion);

  Future<void> setArchived(String id, bool archived) =>
      (update(habits)..where((t) => t.id.equals(id))).write(
        HabitsCompanion(
          archived: Value(archived),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
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
