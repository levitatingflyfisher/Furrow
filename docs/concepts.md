# Concepts

The ideas Furrow is built from, in prose. For exact columns and rules see
[reference/data-model.md](reference/data-model.md) and
[reference/cadences-and-awards.md](reference/cadences-and-awards.md); for why the
choices were made, [adr/](adr/).

## Habit

A **habit** is one thing you're cultivating — "Read", "Drink water", "Meditate".
Every habit has a **cadence** (how it's satisfied), a **schedule** (when it's
expected), a **target**, a colour, and an optional link to a Franklin virtue.
Habits can be archived (kept, hidden) but are not deleted casually. A habit is
one **row** on the Today grid.

## The three cadences

The single most important concept. A habit is satisfied in one of three ways, and
all three live on one grid:

- **Tick (`binary`)** — done or not done today. Target is 1. One tap toggles it.
- **Count (`count`)** — reach N per day, via a stepper. Target is N (e.g. 8
  glasses); `unit` labels it. Tap is +1; long-press is −1.
- **Timer (`duration`)** — accumulate time toward a target. Target is measured in
  **seconds** (1800 = 30 minutes). Logged via the `LogTimeSheet`: quick chips
  (+5/+15/+30), an exact stepper, or a live stopwatch.

The three cadences share one storage model — see
[ADR-0006](adr/0006-three-cadences-one-table.md).

## Mark

A **mark** is a record against a habit on a given day (`dateDay`, stored as a
local `yyyy-MM-dd` string). Completion is stored differently per cadence:

- For **tick/count**, there is **one mark per day**, upserted; `completed` is a
  snapshot the app writes.
- For **duration**, there are **many marks per day** — one per timed session —
  and completion is **derived**: the day is complete when the summed session
  seconds meet the target.

The pure function `dayValue` collapses this: it sums session seconds for a
duration habit, or reads the single row's value otherwise. `dayProgress` turns
that into a `[0,1]` fraction that drives the cell's partial fill.

## Schedule

When a habit is *expected*:

- **`daily`** — every day.
- **`specificDays`** — a chosen set of weekdays, stored as a bit-mask
  (`Mon = bit 0 … Sun = bit 6`).
- **`weeklyCount`** — N times within a calendar week. **Schema-ready but
  UI-deferred**: v1 treats it as "any day". A week-grained schedule and week
  streak are a named [horizon](../VISION.md#horizons-problems-not-a-feature-list).

## Streak

A **streak** is the count of consecutive completed calendar days ending today (or
yesterday, if today is still pending). It is **schedule-naive** in v1 — it counts
calendar days, not scheduled days — and it **resets silently** on any gap: never
red, never a notification. `bestStreak` (the longest run ever) is kept as a calm
record and shown only on Habit Detail. This restraint is deliberate; see
[ADR-0007](adr/0007-no-dark-patterns.md).

## The Franklin thirteen virtues

Benjamin Franklin kept a small book with a grid of thirteen virtues, marking each
day where he fell short and focusing on one virtue per week. Furrow ships his
thirteen — in his own canonical order, each with its precept — as an **optional
seed set** (off by default). A quiet **virtue of the week** rotates through the
thirteen, derived from a fixed Monday anchor date (`virtues[weeksSinceAnchor % 13]`)
independently of any habit rows. Precepts are runtime-overridable via a
`UserPrefs` key (the editor UI is deferred; the key exists). This is where
Furrow's name and shape come from: a book of days, reimagined.

## The FurrowRow grid (the signature surface)

The Today screen renders each habit as a **FurrowRow**: a cadence glyph, the
habit name, and a seven-day strip of inked cells (Mon–Sun). Marking today
**blooms** the cell — the ink rises from the bottom in proportion to the day's
progress, with a minimum visible sliver so a single +1 or logged minute registers
*immediately* instead of staying blank until the whole target lands. A filled
week reads as a furrow cut clean. Interactions are inline, no screen hop:

- **Tap** a cell — logs *today* (toggle / +1 / open the time sheet).
- **Long-press** — fixes a *past* tick inline (binary), or acts on today.

The Today screen has two modes, toggled by a pill: **Flow** (default, the clean
grid) and **Rich** (a denser view).

## Awards

Six **awards**, earned once and kept permanently (never revoked): *First Light*
(first mark), *Seven* (7-day chain), *Whetted* (30-day chain), *Clean Week*
(every active habit met on every scheduled day of a past week), *Full Measure* (a
count habit at target 7 days running), *Deep Hours* (25 hours on one duration
habit). Their unlock checks are **hardcoded** in `AwardService` (v1 has no general
criterion engine); earning any plays a gentle confetti and shows a quiet fact
line. Exact checks: [reference/cadences-and-awards.md](reference/cadences-and-awards.md).

## Ghost mode

Furrow has an auth abstraction with three tiers — **ghost**, **token**, **named** —
but only **ghost** is implemented and it is the whole product: zero identity, zero
server contact. The token and named tiers throw `UnimplementedError` by design.
There is no account and nothing to sign into. See
[ADR-0004](adr/0004-local-first-ghost-mode.md).
