# Reference: data model

The exact on-device schema, defined in
[`lib/core/storage/app_database.dart`](../../lib/core/storage/app_database.dart)
(Drift). `schemaVersion` is **1**, created by a clean `onCreate` — no migrations
yet. All storage is local; there is no server schema.

## `Habits`

One row per habit. Primary key: `id` (text, app-generated UUID).

| Column | Type | Notes |
|---|---|---|
| `id` | text PK | UUID |
| `name` | text | display name |
| `cadence` | text | `binary` \| `count` \| `duration` |
| `scheduleType` | text | default `daily`; also `specificDays`, `weeklyCount` |
| `targetValue` | int | default 1. binary = 1; count = N; **duration = seconds** (1800 = 30 min) |
| `unit` | text? | count label, e.g. `glasses`, `pages` |
| `weekdayMask` | int | default 127 (all days). `Mon = bit 0 … Sun = bit 6` |
| `weeklyTarget` | int? | for `weeklyCount` (UI deferred) |
| `icon` | text? | icon key |
| `colorValue` | int | ARGB; default `0xFFB07A2E` (furrow ochre) |
| `virtueKey` | text? | e.g. `temperance`; null for a user's own habit |
| `archived` | bool | default false |
| `sortOrder` | int | default 0 |
| `createdAt` / `updatedAt` | int | epoch millis |

## `HabitMarks`

One or more rows per habit per day. **Surrogate** primary key: `id` (text) — this
is what lets a duration habit store many session rows for one day.

| Column | Type | Notes |
|---|---|---|
| `id` | text PK | surrogate |
| `habitId` | text → `Habits.id` | FK (enforced; `PRAGMA foreign_keys = ON`) |
| `dateDay` | text | `yyyy-MM-dd`, **local** time |
| `value` | int | binary = 0\|1; count = running n; duration = seconds for *this* session |
| `completed` | bool | snapshot for binary/count; **derived** for duration |
| `startTime` | int? | duration session start (epoch millis) |
| `endTime` | int? | duration session end |
| `durationSecs` | int? | duration session length in seconds |
| `notes` | text? | duration session note |
| `createdAt` / `updatedAt` | int | epoch millis |

**Write patterns:**
- **binary / count** — *upsert* keyed on `(habitId, dateDay)` in app logic: one
  row per day. Concurrent taps are serialized in the repository so they can't
  create a duplicate day row.
- **duration** — *insert* a new row per session; the day's completion is derived
  as `SUM(durationSecs) ≥ Habits.targetValue`.

Index: `ix_marks_habit_day` on `(habit_id, date_day)`.

## `HabitBadges`

The six awards, seeded unearned at `onCreate`. Primary key: `id`.

| Column | Type | Notes |
|---|---|---|
| `id` | text PK | `first_mark`, `chain_7`, `chain_30`, `clean_week`, `count_target_7`, `duration_25h` |
| `kind` | text | a `BadgeKind` name (`firstMark`, `chainDays`, `cleanWeek`, `countTarget`, `durationTotal`, …) |
| `threshold` | int | e.g. 7, 30, 90000 (25h in seconds); 0 where N/A |
| `habitId` | text? → `Habits.id` | null = a global award |
| `earnedAt` | int? | null = unearned; once set, **permanent** (never revoked) |

Seeded rows (`id`, `kind`, `threshold`): `first_mark`/`firstMark`/0 ·
`chain_7`/`chainDays`/7 · `chain_30`/`chainDays`/30 · `clean_week`/`cleanWeek`/0 ·
`count_target_7`/`countTarget`/7 · `duration_25h`/`durationTotal`/90000. Exact
unlock rules: [cadences-and-awards.md](cadences-and-awards.md).

## `UserPrefs`

A small key → value store. Primary key: `key`.

| Column | Type | Notes |
|---|---|---|
| `key` | text PK | e.g. theme, Flow/Rich mode, virtue-seed flag, `virtuePrecept_<key>` |
| `value` | text | serialized value |

A non-empty `UserPrefs` table is also the signal the router uses to decide
whether to show onboarding (empty ⇒ onboarding).

## Notes

- **Dates are local `yyyy-MM-dd` strings**, not timestamps, so a "day" is the
  user's calendar day. Timestamps (`createdAt`/`startTime`/…) are epoch millis.
- **No `Profiles`, `Sessions`, or old `Badges` tables** — those were dropped from
  the Sundial fork; Furrow is single-user, and duration sessions are rows in
  `HabitMarks`.
