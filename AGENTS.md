# AGENTS.md

Guidance for AI coding agents (and humans) working in this repo. This is the
top-level map; when in doubt, the file closest to what you're editing wins.

**Read these, in order, before non-trivial work:**
1. [VISION.md](VISION.md) — what must stay true and why (the invariants).
2. [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md) — how it fits together, with diagrams.
3. [docs/adr/](docs/adr/) — the load-bearing decisions, so you don't re-litigate a settled trade-off.

## Take the code as current-state, not gospel

Every line of source and every comment here was written by an AI assistant. Treat
it as **an accurate record of what currently exists, offered with gratitude and a
grain of salt** — not as a specification and not as guaranteed-correct. A comment
claiming an invariant is a *hypothesis to verify*, not a proof. If a comment and
the tests disagree, the tests win; if the tests and reality disagree, reality
wins. When you rely on a claim, confirm it (read the code, run the test) first.

## What this is

A single-user, **local-first** Flutter habit & daily-virtue tracker. Three
cadences (tick / count / timer) on one seven-day grid; a Franklin thirteen-virtues
seed; six calm awards; ships as an Android APK and an installable web PWA from one
codebase, fully offline. Clean Architecture (domain / data / presentation per
feature), Riverpod for state, Drift over SQLite for storage, `go_router` for
navigation.

## Non-negotiables (breaking one is a regression, not a feature)

- **Stay local-first and offline.** No network calls, no analytics, no BaaS
  (Firebase/Supabase/Auth0), no accounts for core use. The shipped Android build
  must not request the `INTERNET` permission. If you ever add sync, it is
  encrypted blobs through a dumb relay — never plaintext, never a backend that
  can read the data. ([ADR-0004](docs/adr/0004-local-first-ghost-mode.md))
- **No dark patterns.** Streaks never turn red, reset silently, and never trigger
  a punitive notification. Stats stay raw counts, not percentages. No sound, no
  "Achievement Unlocked". If a change would increase engagement by inducing guilt,
  it is wrong here. ([ADR-0007](docs/adr/0007-no-dark-patterns.md))
- **Keep the domain pure.** Logic about habits, cadences, streaks, and awards
  lives in `lib/features/habits/domain/` as plain functions over data — no DB, no
  widgets — so it stays unit-testable. Data access goes through a DAO → repository;
  widgets read providers.
- **TDD, always.** Reproduce → failing test → fix → `flutter test` green → commit.
  Every bugfix ships with a regression test. Pure logic gets a unit test; the
  signature grid is pinned by golden tests.
- **Atomic commits, one concern each.** Commit messages state the *why* and the
  failure mode fixed. **No AI attribution** (`Co-Authored-By` / "Generated with"
  lines) — deliberate project policy. Keep the git history a single neutral
  persona; this repo is public.
- **Never commit** `docs/superpowers/` (local plans/specs), `CLAUDE.md`, or
  `GEMINI.md` — they're gitignored working artifacts. This repo *ships* `AGENTS.md`.

## Where things are (progressive disclosure)

Start with the module map in
[OVERVIEW.md § Module map](docs/architecture/OVERVIEW.md#module-map-where-to-look).
The short version, by concern:

| You're touching… | Go to |
|---|---|
| **Habit / streak / award math** (pure) | `lib/features/habits/domain/` — `habit_logic.dart`, `awards.dart`, `franklin_virtues.dart`, `habit_enums.dart` |
| **The database / schema** | `lib/core/storage/app_database.dart` (Drift tables + `onCreate` seed), `.../data/*_dao.dart` |
| **Reading / writing habits & marks** | `lib/features/habits/data/` — `habits_repository.dart`, `habit_marks_dao.dart`, `award_service.dart` |
| **The Today grid** (signature UI) | `lib/features/habits/presentation/furrow_row.dart`, `today_screen.dart` |
| **Other screens** | `.../presentation/` — `habit_detail_screen.dart`, `stats_screen.dart`, `garden_screen.dart`, `log_time_sheet.dart`, `habit_edit_sheet.dart`; onboarding under `features/onboarding/` |
| **Navigation / app shell** | `lib/core/router/app_router.dart`, `app_shell.dart` |
| **Accounts / ghost mode** | `lib/core/auth/` (`ghost_auth_repository.dart` is the live one) |
| **Settings / preferences** | `lib/features/settings/`, `lib/shared/widgets/mode_pill.dart` (Flow/Rich) |
| **Encrypted backup / restore** | `lib/features/sanctuary_backup/` — `data/backup_serializer.dart` (the JSON envelope + FK-safe restore), `presentation/backup_section.dart` (Settings UI); provider wiring in `lib/main.dart`; built on the sibling `sanctuary_auth_core` / `sanctuary_backup_ui` packages ([ADR-0008](docs/adr/0008-encrypted-backup-seed-phrase.md)) |
| **Theme / colours / spacing** | `lib/shared/theme/` (`app_colors.dart` holds the ochre) |
| **Web shell / PWA** | `web/index.html`, `web/manifest.json` |

Docs are organized [Diátaxis](https://diataxis.fr/)-style — see
[docs/README.md](docs/README.md) for the tutorials / how-to / reference /
explanation split.

## How to work here

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regen *.g.dart (Drift + Riverpod)
flutter test        # unit, widget, and golden suites — green before you commit
flutter analyze     # static analysis — must be clean (package:flutter_lints, no overrides)
flutter run         # launch on a device / emulator / web
```

- `*.g.dart` files (Drift + Riverpod codegen) are **gitignored**. Run
  `build_runner` after every fresh checkout or dependency change, or the build
  fails on missing `*.g.dart` imports.
- Golden tests are environment-sensitive (font rasterisation) and are **tagged
  and excluded from CI**; regenerate them locally with
  `flutter test --update-goldens test/visual/` when you deliberately change the
  grid's appearance.
- Adding a feature? Follow the existing shape: `domain/` (entities + pure logic +
  abstract repository) → `data/` (Drift DAO + repository impl) → `presentation/`
  (screens, widgets, Riverpod providers). New tables go in
  `app_database.dart`; bump `schemaVersion` and add a migration if you change an
  existing one (v1 is a clean `onCreate`).

## When you're unsure

Prefer the calm choice to the engaging one. Prefer a failing test to a plausible
fix. Prefer matching the surrounding code to introducing a new pattern. Prefer
keeping the domain pure to threading a database through a widget. When in doubt
about a decision's rationale, grep [docs/adr/](docs/adr/) before reopening it —
you may be re-litigating something already settled.
