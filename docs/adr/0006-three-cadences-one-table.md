# ADR-0006: Three cadences on one `Habits` table

- **Status:** Accepted
- **Date:** 2026-07-03

## Context

Furrow tracks three genuinely different shapes of habit: a **tick** (done / not),
a **count** (reach N per day), and a **timer** (accumulate seconds toward a
target). The signature Today grid must show all three on one uniform seven-day
row, and the domain logic (progress, completion, streak) must treat them
uniformly enough to share one grid but faithfully enough to be correct. A naive
"one table per cadence" design would triple the schema and the query surface.

## Decision

**Model all three cadences in one `Habits` table with a `cadence` discriminator,
and record marks in one `HabitMarks` table with a surrogate primary key.**

- `Habits.cadence ∈ {binary, count, duration}`; `targetValue` means 1 (binary),
  N (count), or **seconds** (duration). `unit` labels a count ("glasses").
- `HabitMarks` has a surrogate `id` PK so **duration** habits can store *many
  session rows per day*. Binary/count are *upserted* keyed on
  `(habitId, dateDay)` in app logic — one row per day.
- `completed` is a **snapshot** for binary/count, but for duration it is
  **derived**: a day is complete when `SUM(durationSecs) ≥ targetValue`. The
  domain function `dayValue` sums session seconds for duration and reads the
  single row otherwise.
- The grid cell fills to `dayProgress ∈ [0,1]` (with a minimum visible sliver)
  so a single +1 or logged minute is acknowledged immediately.

## Consequences

- **Buys:** one uniform grid, one query surface, one set of domain functions.
  Duration's session model (start/end/notes per session) is expressible without a
  second marks table.
- **Costs:** cadence-conditional logic in a few pure functions (`dayValue`,
  `completedDayKeys`), and a subtlety worth remembering — **binary/count are
  one-row-per-day upserts; duration is many-rows-per-day inserts**. Concurrent
  taps on the same day are serialized in the repository so they can't create a
  duplicate day row.
- **Forecloses:** nothing — `weeklyCount` and a `weeklyTarget` column already sit
  in the schema for a future week-grained cadence.

## Alternatives considered

- **One table per cadence:** rejected — triples schema and queries; the grid would
  have to union three shapes back together anyway.
- **One row per day for duration too (accumulate into a single row):** rejected —
  loses per-session data (start/end/notes) and makes concurrent session writes
  lossy; the surrogate-PK, many-rows model keeps sessions intact.
