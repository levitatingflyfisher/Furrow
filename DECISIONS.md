# Furrow — design decisions

> A calm, local-first daily-virtue & habit grid for households, in the spirit of
> Benjamin Franklin's thirteen-virtues book of days and Aristotelian habituation.
> Forked from Sundial. *"We are what we repeatedly do."*

Decisions below were reached via an SGCM design pass (Scout the Sundial fork
base → Generate model/UX/gamification/name → Critic → Mediator). Logged here per
the working agreement; not re-litigated.

## Identity
- **Name:** Furrow — a plough-groove deepened by each repeated pass; holds all
  three cadences (a tick, a count, a duration) on one visual line. Chosen over
  "Whetstone" because the furrow metaphor carries *accumulation* natively and is
  visually nothing like Sundial's gnomon (good fork differentiation).
- **Tagline:** *We are what we repeatedly do.*
- **Package:** `com.openhearth.furrow` · Dart pkg `furrow`
- **Accent (tilled-earth ochre, distinct from sage/terracotta/slate siblings):**
  `furrow500 #B07A2E` / `furrow600 #8F6122` / `furrow700 #6E4A19`.
  Kept `onPace` green and `behind`/`sunGold` amber (semantic, not brand).

## v1 scope
- **In:** 3 cadences (binary tick / count stepper / duration timer — duration
  reuses Sundial's timer stack); single-user (profiles ripped); `daily` +
  `specificDays` schedules; Franklin 13-virtue seed (off by default) +
  virtue-of-the-week banner; the **Today "FurrowRow" grid** (signature, Flow
  mode default); Habit Detail (calm streak + heatmap); Stats (raw counts, no
  %); 6 awards + gentle confetti; onboarding with starter templates; local font
  bundling.
- **Deferred (schema-ready):** weeklyCount schedule + week streaks; per-virtue
  precept editing; a general award-criterion engine (v1 hardcodes ~6 checks);
  partial-fill home glyphs; home-screen widget metric rework.
- **Cut:** loss-recovery "Return" award; missed-day "Erratum" reflection award.

## Data model (drift, schemaVersion 1, clean onCreate)
- `Habits`(id, name, cadence[binary|count|duration], scheduleType, targetValue,
  unit?, weekdayMask, weeklyTarget?, icon?, colorValue, virtueKey?, archived,
  sortOrder, createdAt, updatedAt).
- `HabitMarks`(**surrogate id PK**, habitId→Habits, dateDay 'yyyy-MM-dd' local,
  value, completed, startTime?/endTime?/durationSecs?/notes? for duration,
  timestamps). Binary/count upsert keyed on (habitId,dateDay); duration is
  many-rows-per-day (sessions). `completed`: snapshot for binary/count; **derived**
  (SUM(secs)≥target) for duration.
- `HabitBadges`(id, kind, threshold, habitId?, earnedAt?) — earned = permanent.
- Drop `Profiles`, old `Sessions`, old `Badges`. Keep `UserPrefs` + the drift
  web-connection block (rename db `sundial`→`furrow`).
- **Streak:** consecutive completed calendar days, schedule-naive in v1; resets
  silently (never red, no notification); `bestChainDays` kept as a calm record;
  shown only on Habit Detail.

## Gamification (6 awards, hardcoded checks reusing Sundial's badge pattern)
First Light (first mark) · Seven (7-day chain) · Whetted (30-day chain) ·
Clean Week (all active habits met one week) · Full Measure (count target 7 days)
· Deep Hours (25h on a duration habit). Gentle confetti (furrow/gold/linen, slow
drift) + a quiet Lora fact line; no "Achievement Unlocked", no sound.

## Deploy
PWA → gh-pages (manual; gate on `build/web/main.dart.js`; restore patched
index.html with spinner + SW self-heal + `navigator.storage.persist()`). APK →
`v*.*.*` tag triggers in-repo `release.yml` (split-per-abi). Landing card on
`levitatingflyfisher.github.io` (PWA + sideload APK).

## Post-launch input-flow fixes (2026-06-25)
User feedback: logging some habits felt clunky / too many clicks/screens. Root
causes found (systematic-debugging) and fixed:
- **No sub-target feedback (the bigger half).** `_DayCell` filled only at FULL
  target (`completedDayKeys` returns target-met days only), so a +1 of 8 or
  +5 of 20 min left the cell blank — tapping looked like nothing happened. Fix:
  new pure `dayProgress(h, marks, day)→[0,1]` drives a **partial bloom** that
  rises from the bottom of the cell (min visible sliver ≥0.18), so every tap is
  acknowledged at once. Affects count AND duration cells.
- **Duration forced a screen hop + a live stopwatch.** Tapping a duration cell
  pushed the whole Detail screen, then a button, then a stopwatch-only sheet,
  and there was no way to log a KNOWN time after the fact. Fix: a single shared
  `LogTimeSheet` (`showLogTimeSheet`) opens directly from the Today cell — quick
  -add chips (+5/+15/+30, log in one tap, prominent), an exact stepper, and the
  live stopwatch kept secondary (collapsed `ExpansionTile`). Same sheet reused
  by Detail's "Log time" button (the old `_TimerSheet` was deleted — dedup).
- **Count kept +1 tap / −1 long-press by deliberate choice** (the right
  affordance for water-glasses); the partial fill now makes each +1 visible, so
  the "did that register?" friction is gone without changing the input.
- Tests-first (TDD): `dayProgress` unit cases + a deterministic widget test
  (tap duration cell → +15 chip → assert a 900-s `HabitMark`) that dodges the
  live-Timer teardown trap. Today goldens regenerated (Water 5/8 + Read 12/20
  now show partial fills).

## Post-launch round 2 (2026-06-25): FAB collision + inline past-edit
- **"+Habit" moved from a FAB to an app-bar action.** The extended FAB floated
  over the bottom grid rows and intercepted taps meant for their day-cells (the
  user hit it while trying to log time on a lower habit). An app-bar "+" is
  always reachable and never floats over content; the grid's bottom padding
  dropped 96→`AppSpacing.lg` accordingly.
- **Logging stays screen-free** (confirmed, not changed): tap = inline
  (binary toggle / count +1 / duration → the `LogTimeSheet`, a modal *sheet*,
  not a route). The detail screen is only for viewing stats.
- **Editing a prior entry no longer needs a screen.** Long-press now toggles a
  **past binary day** inline (cells carry `ValueKey('day_<id>_<yyyy-MM-dd>')`;
  today keeps `today_<id>`). Count −1 / duration sheet stay today-only by
  design; past count/duration edits still use the detail screen (deferred —
  they'd need a day-parameterised sheet). TDD: a deterministic widget test
  long-presses the week's Monday cell (a past day, or today on Mondays) and
  asserts the toggle. 43 tests green.
