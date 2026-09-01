import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/award_service.dart';
import 'package:furrow/features/habits/data/awards_dao.dart';
import 'package:furrow/features/habits/data/habit_marks_dao.dart';
import 'package:furrow/features/habits/data/habits_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/awards.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';

/// VISION claims "six gently earned awards". This is what makes the claim
/// true: exactly six exist, the screen describes the same six the database
/// holds, every one of them can be earned (the chain awards on a habit with
/// days off, which schedule-blind streaks made impossible), and once earned
/// an award stays earned whatever happens to the marks or the habit.
const _monWedFri = 1 | 4 | 16;

void main() {
  late AppDatabase db;
  late HabitsRepository repo;
  late AwardsDao awards;
  late AwardService service;

  // A Friday; everything below happens in the ten weeks before it.
  final now = DateTime(2026, 7, 17, 20);
  final longAgo = DateTime(2026, 1, 5);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitsRepository(HabitsDao(db), HabitMarksDao(db));
    awards = AwardsDao(db);
    service = AwardService(repo, awards);
  });
  tearDown(() => db.close());

  Future<Set<String>> earned() async => {
        for (final a in await awards.getAll())
          if (a.earnedAt != null) a.id
      };

  Future<Habit> plant(
    String name,
    Cadence cadence, {
    int target = 1,
    int mask = kDailyMask,
  }) async {
    final id = await withClock(
        Clock.fixed(longAgo),
        () => repo.createHabit(
              name: name,
              cadence: cadence,
              targetValue: target,
              scheduleType: mask == kDailyMask
                  ? ScheduleType.daily
                  : ScheduleType.specificDays,
              weekdayMask: mask,
            ));
    return (await repo.getHabit(id))!;
  }

  /// The last [n] scheduled days of [h] up to [now], oldest first.
  List<String> lastScheduledDays(Habit h, int n) {
    final out = <String>[];
    var d = DateTime(now.year, now.month, now.day);
    while (out.length < n) {
      if (h.weekdayMask.includesWeekday(d.weekday)) out.add(d.toDateDay());
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return out.reversed.toList();
  }

  test('exactly six awards, and the screen describes the same six', () async {
    final seeded = (await awards.getAll()).map((a) => a.id).toSet();
    expect(seeded, hasLength(6));
    expect(kAwardMeta.map((a) => a.id).toSet(), seeded);
    for (final a in kAwardMeta) {
      expect(a.description, isNotEmpty, reason: a.id);
    }
  });

  test('every award can be earned, the chains on a Mon/Wed/Fri habit',
      () async {
    final gym = await plant('Gym', Cadence.binary, mask: _monWedFri);
    for (final d in lastScheduledDays(gym, 30)) {
      await repo.setBinary(gym, d, true);
    }
    final water =
        await plant('Water', Cadence.count, target: 3, mask: _monWedFri);
    for (final d in lastScheduledDays(water, 7)) {
      await repo.adjustCount(water, d, 3);
    }
    final read = await plant('Read', Cadence.duration, target: 60);
    await repo.addDurationSession(read, now.toDateDay(),
        startMillis: 0, endMillis: 1, durationSecs: 90000);
    // Clean Week: last week, every habit met on every scheduled day. Read
    // is daily, so it needs all seven.
    final lastMonday = DateTime(now.year, now.month, now.day).startOfWeek;
    for (var i = 1; i <= 7; i++) {
      await repo.addDurationSession(
          read, DateTime(lastMonday.year, lastMonday.month, lastMonday.day - i)
              .toDateDay(),
          startMillis: 0, endMillis: 1, durationSecs: 60);
    }

    await service.recheck(now: now);
    expect(await earned(), kAwardMeta.map((a) => a.id).toSet());
  });

  test('an earned award is never taken back', () async {
    final walk = await plant('Walk', Cadence.binary);
    await repo.setBinary(walk, now.toDateDay(), true);
    await service.recheck(now: now);
    expect(await earned(), contains('first_mark'));

    await repo.clearMarks(walk.id);
    await service.recheck(now: now);
    expect(await earned(), contains('first_mark'));

    await repo.removeHabit(walk.id);
    await service.recheck(now: now);
    await repo.deleteHabitForever(walk.id);
    await service.recheck(now: now);
    expect(await earned(), contains('first_mark'));
  });
}
