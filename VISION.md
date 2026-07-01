# Vision

> The north star for Furrow. If you (person or agent) are about to change
> something load-bearing, read this first — it says what must stay true and why.
> For *how it's built*, see [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md);
> for *why each decision was made*, [docs/adr/](docs/adr/).

## The one idea

**Practice, not pressure.** Furrow is a daily-virtue and habit tracker built on
one conviction: the tools that help you become who you want to be should be
*calm*. Benjamin Franklin carried a small book with a grid of thirteen virtues
and marked it every night — not to win a streak, but to notice. Furrow is that
book of days, reimagined for a phone, with the engagement-maximizing machinery
deliberately left out.

The metaphor is a **furrow**: a plough-line deepened by each repeated pass. A
habit is one row; a day is one cell; marking today blooms the ink upward. Fill a
week and the row reads as a groove cut clean. Accumulation is the reward — there
is nothing else to chase.

## What this is

A single-user, **local-first** Flutter app. It holds three kinds of habit on one
seven-day grid:

- a **tick** — done or not (meditate today),
- a **count** — reach N per day (8 glasses of water),
- a **timer** — accumulate time toward a target (30 minutes reading).

It ships an optional **Franklin thirteen-virtues** seed, a quiet virtue-of-the-week
banner, a calm Habit Detail view (streak + heatmap), plain-count Stats, and six
gently-earned awards. It runs on Android (APK) and the web (installable PWA) from
one codebase, entirely offline.

It is **not** a social app, a coach, or a productivity system with a funnel. It
does not want your attention for its own sake.

## Design commitments (the invariants)

These are the load-bearing beliefs Furrow shares with the rest of the OpenHearth
family. Breaking one is a design regression, not a feature. Each is recorded as
an ADR and, where it's checkable, enforced in tests.

1. **Local-first, and here, local-only.** Everything lives in an on-device SQLite
   database ([Drift](docs/adr/0003-drift-over-sqflite.md)). Furrow works fully
   offline with no degraded mode, because offline *is* the mode. There is no
   sync server today; if one is ever added it must travel as encrypted blobs
   through a dumb relay — never a BaaS, never plaintext.
   ([ADR-0004](docs/adr/0004-local-first-ghost-mode.md))
2. **No account, ever, for core use.** "Ghost mode" — zero identity, zero server
   contact — is the product, not a trial tier. The auth layer defaults to a ghost
   repository; Sync/Named tiers are unimplemented stubs, and the app is complete
   without them.
3. **No ads, no tracking, no data sales.** Enforced architecturally: the shipped
   Android build declares no `INTERNET` permission, and there is no network code
   in the app. This is *checkable*, not just promised — see
   [privacy model](docs/privacy-model.md).
4. **Calm over engagement.** Streaks never turn red, reset silently, and never
   send a "you broke your streak" nudge. Stats are raw counts, not percentages
   of shame. No sound, no "Achievement Unlocked". A habit tracker that punishes
   you for living is a habit tracker you delete. ([ADR-0007](docs/adr/0007-no-dark-patterns.md))
5. **FLOSS / open by default.** MIT-licensed. The code is a recipe worth sharing.
6. **Genuine craft.** Clean Architecture on Flutter (domain / data / presentation
   per feature), pure domain logic covered by unit tests, the signature grid
   pinned by golden tests. Warm, not sterile — home-cooked software.

## Honest scorecard — built vs. aspirational

A guiding light has to tell the truth about where the light reaches. Every line
of this code and every comment in it was written by an AI assistant; treat them
as **an accurate record of what currently exists, offered with gratitude and a
grain of salt** — not as a specification, and not as guaranteed-correct. Verify a
claim (read the code, run the test) before you rely on it. As of v0.1.0:

**Real, tested, load-bearing:**
- The full loop: create a habit → mark it on the Today grid → the cell blooms →
  awards re-check → gentle confetti. All three cadences (tick / count / timer)
  work end-to-end and persist in Drift.
- The **FurrowRow** signature grid with partial-bloom cells (a single +1 or a
  logged minute is acknowledged immediately, not held back until the target
  lands) — pinned by golden tests across phone/tablet and text-scale 1×–3×.
- Pure domain logic (`habit_logic.dart`): day value, progress, completion,
  current/best streak, clean-week — unit-tested.
- The Franklin thirteen-virtues seed + virtue-of-the-week rotation.
- Six awards with hardcoded, earned-once checks; inline logging (tap = today,
  long-press = fix a past tick) with no screen hop.
- Fully offline on Android (APK) and web (PWA), fonts bundled, boot spinner and
  service-worker self-heal baked into the web shell.
- **Encrypted backup and restore** (`.ohbk`, a 12-word recovery phrase, no
  server) — Settings → Encrypted Backup. A manual backup you carry yourself,
  not sync. ([ADR-0008](docs/adr/0008-encrypted-backup-seed-phrase.md))

**Aspirational — documented, not shipped:**
- **Sync / multi-device / multi-user.** The auth layer is ghost-only; token and
  named tiers throw `UnimplementedError`. There are no profiles — Furrow is
  single-user by design in v1.
- **`weeklyCount` schedules and week-grained streaks.** The schema carries the
  columns; the UI treats them as "any day" for now.
- **Per-virtue precept editing** (the `UserPrefs` key exists; no editor),
  **a general award-criterion engine** (v1 hardcodes six checks), and
  **home-screen widget** depth.

The core practice — cultivate a habit, mark it daily, watch the furrow deepen —
is real and shipped. Anything involving another device, another person, or a
week-grained schedule is still a hope. Keep that line bright.

## Horizons (problems, not a feature list)

Framed as problems on purpose — a dated feature list self-destructs.

- **Near** — Make `weeklyCount` real: a habit you do *N times a week* rather than
  on fixed days, with a streak that counts weeks, not days. The schema is ready;
  the calm week-grained UI is the open design problem.
- **Mid** — Let households share a device gracefully without reintroducing the
  accounts we deliberately cut: lightweight, on-device "who's marking" without a
  login. And a general award-criterion engine so new awards are data, not code.
- **Far** — The honest hard one: **calm without abandonment.** A tracker that
  never nags is a tracker easy to forget. The unsolved problem is a gentle,
  non-manipulative way to stay present in someone's week — a nudge that respects
  a person rather than farming them. Nobody in this category has solved it well;
  we would rather ship nothing than ship a dark pattern.

## The name

**Furrow** — a groove cut into earth by a plough, deepened by each repeated pass.
It carries *accumulation* natively (a furrow is the record of every pass over it)
and it holds all three cadences on one visual line. It was chosen over
"Whetstone" partly because a furrow is visually nothing like a sundial's gnomon —
Furrow is forked from Sundial, a sibling OpenHearth app, and a good fork should
not be mistaken for its parent.
