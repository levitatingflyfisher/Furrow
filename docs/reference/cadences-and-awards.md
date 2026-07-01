# Reference: cadences, progress, streaks & awards

The precise rules, as implemented in
[`habit_logic.dart`](../../lib/features/habits/domain/habit_logic.dart),
[`award_service.dart`](../../lib/features/habits/data/award_service.dart), and
[`awards.dart`](../../lib/features/habits/domain/awards.dart). These are pure
functions — read them as the source of truth; this page mirrors them.

## Cadences

| Cadence | `targetValue` means | A day's value | Complete when |
|---|---|---|---|
| `binary` | 1 | the single row's `value` (0 or 1) | `value ≥ 1` |
| `count` | N (target per day) | the single row's `value` | `value ≥ N` |
| `duration` | **seconds** (1800 = 30 min) | `SUM(durationSecs)` of that day's sessions | `sum ≥ targetValue` |

## Progress and completion

- **`dayValue(habit, dayMarks)`** — sums session seconds for a duration habit;
  otherwise returns the single day-row's `value` (0 if none).
- **`isMet(habit, value)`** — `value ≥ targetValue` (binary target is 1).
- **`dayProgress(habit, marks, day) → [0,1]`** — `value / targetValue`, clamped.
  If `targetValue ≤ 0`, any positive value is `1.0`. This drives the cell's
  partial bloom; the widget renders any nonzero progress with a **minimum visible
  sliver (0.18)** so a single tap registers immediately.
- **`completedDayKeys(habit, marks) → Set<yyyy-MM-dd>`** — for duration, the set
  of days whose summed seconds meet the target; otherwise the set of days whose
  mark is `completed`.

## Streaks

- **`currentStreak(habit, marks, today)`** — consecutive completed calendar days
  ending today, *or* ending yesterday if today isn't done yet (so a not-yet-marked
  today doesn't zero a live streak). **Schedule-naive**; resets to 0 on any gap.
- **`bestStreak(habit, marks)`** — the longest run of consecutive completed
  calendar days ever. Kept as a calm record (`bestChainDays`), shown only on
  Habit Detail.
- **`completedDayCount(habit, marks)`** — total completed days (for Stats; raw
  count, no percentage).

Calendar days, not scheduled days — a deliberate v1 simplification (see
[limitations](../limitations.md)).

## Schedules

**`isScheduledOn(habit, day)`**:
- `daily` → true every day.
- `weeklyCount` → treated as true every day in v1 (week-grained UI deferred).
- `specificDays` → true when `weekdayMask` includes that weekday
  (`Mon = bit 0 … Sun = bit 6`; `kDailyMask = 127`).

## Virtue of the week

**`virtueOfWeek(anchorMonday, now)`** = `kFranklinVirtues[weeksSinceAnchor % 13]`,
guarded for negative weeks. Derived from a fixed Monday anchor, independent of any
habit rows. The thirteen virtues are stored in Franklin's canonical order (never
alphabetical), each with its precept; precepts are overridable via the
`UserPrefs` key `virtuePrecept_<key>` (editor UI deferred).

## The six awards

Earned once, permanently (never revoked). Checked by `AwardService.recheck()`
after every mark; any newly-earned award triggers gentle confetti and a quiet
fact line. Checks are **hardcoded** (no general criterion engine in v1).

| id | Name | Earned when | Check |
|---|---|---|---|
| `first_mark` | First Light | your first completed mark on any habit | any habit has ≥1 completed day |
| `chain_7` | Seven | a 7-day chain on any one habit | `bestStreak(h) ≥ 7` |
| `chain_30` | Whetted | a 30-day chain on any one habit | `bestStreak(h) ≥ 30` |
| `count_target_7` | Full Measure | a **count** habit at full target 7 days running | count habit with `bestStreak(h) ≥ 7` |
| `duration_25h` | Deep Hours | 25 hours logged on one **duration** habit | duration habit with total `durationSecs ≥ 90000` |
| `clean_week` | Clean Week | every active habit met on every scheduled day of one past week | see below |

**Clean Week** scans the last 8 fully-elapsed Mon–Sun weeks. A week qualifies if,
for every active habit that already existed at the week's Monday, every *scheduled*
day that week is in that habit's completed set — and at least one habit was
scheduled that week. A habit created mid-week disqualifies that week.

Award display metadata (name, description, icon, fact line) lives in `kAwardMeta`
in `awards.dart`; earn-state lives in the `HabitBadges` table.
