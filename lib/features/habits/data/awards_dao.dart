// lib/features/habits/data/awards_dao.dart
import 'package:drift/drift.dart';
import 'package:furrow/core/storage/app_database.dart';

part 'awards_dao.g.dart';

@DriftAccessor(tables: [HabitBadges])
class AwardsDao extends DatabaseAccessor<AppDatabase> with _$AwardsDaoMixin {
  AwardsDao(super.db);

  Stream<List<HabitBadge>> watchAll() =>
      (select(habitBadges)..orderBy([(t) => OrderingTerm.asc(t.threshold)]))
          .watch();

  Future<List<HabitBadge>> getAll() => select(habitBadges).get();

  Future<HabitBadge?> getById(String id) =>
      (select(habitBadges)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Marks an award earned (permanent — never revoked). No-op if already earned.
  Future<void> earn(String id, int earnedAt) =>
      (update(habitBadges)
            ..where((t) => t.id.equals(id) & t.earnedAt.isNull()))
          .write(HabitBadgesCompanion(earnedAt: Value(earnedAt)));
}
