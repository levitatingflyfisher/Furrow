import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';

/// checklist-manifesto-01 (finding 7): planting Franklin's thirteen virtues
/// put thirteen rows on an evening's checklist at once. Franklin worked one
/// virtue a week; the seed now plants this week's virtue active and the
/// other twelve resting, and the weekly rotation wakes each one when its
/// week comes. A virtue the household rests or wakes by hand is theirs: the
/// rotation never touches it again.
void main() {
  late AppDatabase db;
  late HabitsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
  });
  tearDown(() => db.close());

  Future<Habit> virtue(String key) async =>
      (await db.select(db.habits).get()).firstWhere((h) => h.virtueKey == key);

  test('the seed plants this week\'s virtue active and twelve resting',
      () async {
    final r = await repo.seedFranklinVirtues(focusKey: 'silence');
    expect(r.planted, 13);
    final rows = await db.select(db.habits).get();
    expect(rows.where((h) => !h.archived).map((h) => h.virtueKey),
        ['silence']);
    expect(rows.where((h) => h.archived), hasLength(12));
  });

  test('the rotation wakes a waiting virtue when its week comes', () async {
    await repo.seedFranklinVirtues(focusKey: 'temperance');
    expect((await virtue('silence')).archived, isTrue);

    expect(await repo.promoteFocusVirtue('silence'), isTrue);
    expect((await virtue('silence')).archived, isFalse);
    expect((await virtue('temperance')).archived, isFalse,
        reason: 'nothing earned is taken away: last week\'s stays');

    expect(await repo.promoteFocusVirtue('silence'), isFalse,
        reason: 'once is enough');
  });

  test('a virtue rested by hand is never woken by the rotation', () async {
    await repo.seedFranklinVirtues(focusKey: 'temperance');
    final order = await virtue('order');
    await repo.setArchived(order.id, false); // woken by hand
    await repo.setArchived(order.id, true); // and rested by hand

    expect(await repo.promoteFocusVirtue('order'), isFalse);
    expect((await virtue('order')).archived, isTrue);
  });

  test('a removed waiting virtue is not woken', () async {
    await repo.seedFranklinVirtues(focusKey: 'temperance');
    final silence = await virtue('silence');
    await repo.removeHabit(silence.id);
    expect(await repo.promoteFocusVirtue('silence'), isFalse);
    expect((await virtue('silence')).archived, isTrue);
  });
}
