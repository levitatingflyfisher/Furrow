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
