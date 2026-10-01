import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/franklin_virtues.dart';

/// Planting Franklin's virtues twice must not plant them twice
/// (furrow:checklist-manifesto-01): the guard read only active habits, so a
/// resting virtue was planted again, and Settings always said "planted".
void main() {
  late AppDatabase db;
  late HabitsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
  });
  tearDown(() => db.close());

  Future<List<Habit>> virtueRows() async =>
      (await db.select(db.habits).get())
          .where((h) => h.virtueKey != null)
          .toList();

  test('first plant: thirteen planted', () async {
    final r = await repo.seedFranklinVirtues(focusKey: 'temperance');
    expect(r.planted, 13);
    expect(seedMessage(r),
        'Planted the thirteen virtues. Temperance is this week’s; the other '
        'twelve rest until their week comes.');
  });

  test('a resting virtue is not planted a second time', () async {
    await repo.seedFranklinVirtues(focusKey: 'temperance');
    final order = (await virtueRows())
        .firstWhere((h) => h.virtueKey == 'order');
    await repo.setArchived(order.id, false);
    await repo.setArchived(order.id, true);

    final r = await repo.seedFranklinVirtues(focusKey: 'temperance');
    expect(r.planted, 0);
    expect(r.resting, 12, reason: 'eleven waiting for their week, and Order');
    expect(await virtueRows(), hasLength(13));
    expect(seedMessage(r),
        'All thirteen are already planted. 12 are resting; find them under '
        'Resting below.');
  });

  test('a removed virtue is brought back, not duplicated', () async {
    await repo.seedFranklinVirtues(focusKey: 'temperance');
    final silence = (await virtueRows())
        .firstWhere((h) => h.virtueKey == 'silence');
    await repo.removeHabit(silence.id);

    final r = await repo.seedFranklinVirtues(focusKey: 'temperance');
    expect(r.planted, 0);
    expect(r.restored, 1);
    expect(await virtueRows(), hasLength(13));
    expect((await repo.getHabit(silence.id))!.deletedAt, isNull);
    expect(seedMessage(r), 'Brought back 1 you had removed.');
  });

  test('a partly planted set plants only what is missing', () async {
    await repo.seedFranklinVirtues(focusKey: 'temperance');
    final rows = await virtueRows();
    for (final h in rows.take(4)) {
      await repo.deleteHabitForever(h.id);
    }
    final r = await repo.seedFranklinVirtues(focusKey: 'temperance');
    expect(r.planted, 4);
    expect(seedMessage(r),
        'Planted 4 of the thirteen virtues. Temperance is this week’s; the '
        'other 3 rest until their week comes.');
  });
}
