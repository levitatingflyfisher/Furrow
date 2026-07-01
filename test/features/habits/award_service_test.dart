import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/award_service.dart';
import 'package:furrow/features/habits/data/awards_dao.dart';
import 'package:furrow/features/habits/data/habits_repository.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';

class _MockRepo extends Mock implements HabitsRepository {}

class _MockAwards extends Mock implements AwardsDao {}

Habit _habit({int createdAt = 0}) => Habit(
      id: 'h',
      name: 'Test',
      cadence: Cadence.binary.name,
      scheduleType: ScheduleType.daily.name,
      targetValue: 1,
      weekdayMask: kDailyMask,
      colorValue: 0xFFB07A2E,
      archived: false,
      sortOrder: 0,
      createdAt: createdAt, // default: existed long before any scanned week
      updatedAt: 0,
    );

HabitMark _mark(String day) => HabitMark(
      id: 'h-$day',
      habitId: 'h',
      dateDay: day,
      value: 1,
      completed: true,
      durationSecs: null,
      createdAt: 0,
      updatedAt: 0,
    );

const _cleanWeekBadge = HabitBadge(
  id: 'clean_week',
  kind: 'cleanWeek',
  threshold: 0,
  habitId: null,
  earnedAt: null,
);

void main() {
  late _MockRepo repo;
  late _MockAwards awards;

  setUp(() {
    repo = _MockRepo();
    awards = _MockAwards();
    when(() => awards.getAll()).thenAnswer((_) async => [_cleanWeekBadge]);
    when(() => awards.earn(any(), any())).thenAnswer((_) async {});
    when(() => repo.activeHabitsOnce()).thenAnswer((_) async => [_habit()]);
  });

  test(
      'clean_week finds a fully-marked week even when checked just after '
      'midnight two DST-crossing weeks later', () async {
    // The week of Mon 2026-03-02..Sun 2026-03-08 (the US spring-forward
    // week) is fully marked. Checking on Fri 2026-03-20 at 00:30: the old
    // Duration(days: 7 * w) walk back from a just-after-midnight cursor
    // slid to 23:30 of the previous day in a DST zone (TZ=America/Denver)
    // and scanned Mar 1..7 instead — missing the clean week.
    final marks = [
      for (var d = 2; d <= 8; d++)
        _mark('2026-03-${d.toString().padLeft(2, '0')}'),
    ];
    when(() => repo.allMarksOnce()).thenAnswer((_) async => marks);

    final earned = await AwardService(repo, awards)
        .recheck(now: DateTime(2026, 3, 20, 0, 30));

    expect(earned.map((b) => b.id), ['clean_week']);
    verify(() => awards.earn('clean_week', any())).called(1);
  });

  test(
      'clean_week counts a habit created ON the Monday of the marked week '
      '(creation day, not creation instant, gates eligibility)', () async {
    // Created Monday 2026-03-02 at 14:00 — after Monday *midnight* but on
    // the Monday itself. An instant-level isAfter(monday) guard makes such
    // a habit permanently ineligible for that week's clean_week even
    // though every scheduled day (Mon..Sun) is marked.
    final created = DateTime(2026, 3, 2, 14).millisecondsSinceEpoch;
    when(() => repo.activeHabitsOnce())
        .thenAnswer((_) async => [_habit(createdAt: created)]);
    final marks = [
      for (var d = 2; d <= 8; d++)
        _mark('2026-03-${d.toString().padLeft(2, '0')}'),
    ];
    when(() => repo.allMarksOnce()).thenAnswer((_) async => marks);

    final earned = await AwardService(repo, awards)
        .recheck(now: DateTime(2026, 3, 20, 0, 30));

    expect(earned.map((b) => b.id), ['clean_week'],
        reason: 'a Monday-created habit with a fully marked Mon..Sun week '
            'must earn clean_week');
    verify(() => awards.earn('clean_week', any())).called(1);
  });

  test(
      'clean_week still skips a habit created mid-week (Tuesday) of the '
      'only marked week', () async {
    final created = DateTime(2026, 3, 3, 9).millisecondsSinceEpoch;
    when(() => repo.activeHabitsOnce())
        .thenAnswer((_) async => [_habit(createdAt: created)]);
    final marks = [
      for (var d = 2; d <= 8; d++)
        _mark('2026-03-${d.toString().padLeft(2, '0')}'),
    ];
    when(() => repo.allMarksOnce()).thenAnswer((_) async => marks);

    final earned = await AwardService(repo, awards)
        .recheck(now: DateTime(2026, 3, 20, 0, 30));

    expect(earned, isEmpty,
        reason: 'the habit did not exist for the whole week');
    verifyNever(() => awards.earn(any(), any()));
  });

  test(
      'recheck derives both "today" and the earn stamp from clock.now(), '
      'not the wall clock', () async {
    // Production callers omit [now]; goldens and midnight-tear tests pin
    // the date with withClock. If recheck falls back to DateTime.now()
    // the scan window and the earnedAt stamp both tear away from the
    // clock the rest of the app (TodayScreen) renders under.
    final marks = [
      for (var d = 2; d <= 8; d++)
        _mark('2026-03-${d.toString().padLeft(2, '0')}'),
    ];
    when(() => repo.allMarksOnce()).thenAnswer((_) async => marks);

    final pinned = DateTime(2026, 3, 20, 0, 30);
    final earned = await withClock(
        Clock.fixed(pinned), () => AwardService(repo, awards).recheck());

    expect(earned.map((b) => b.id), ['clean_week'],
        reason: 'the scan window must be computed from the pinned clock');
    verify(() =>
            awards.earn('clean_week', pinned.millisecondsSinceEpoch))
        .called(1);
  });

  test('clean_week is not earned when a scheduled day is unmarked', () async {
    final marks = [
      for (var d = 2; d <= 7; d++) // Sunday 03-08 missing
        _mark('2026-03-${d.toString().padLeft(2, '0')}'),
    ];
    when(() => repo.allMarksOnce()).thenAnswer((_) async => marks);

    final earned = await AwardService(repo, awards)
        .recheck(now: DateTime(2026, 3, 20, 0, 30));

    expect(earned, isEmpty);
    verifyNever(() => awards.earn(any(), any()));
  });
}
