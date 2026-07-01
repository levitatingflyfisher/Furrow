# Furrow

> **We are what we repeatedly do.** A calm, local-first daily-virtue & habit
> grid for households — Benjamin Franklin's thirteen-virtues book of days,
> reimagined without streak-shaming or dark patterns.

Furrow is a small Flutter app for tracking the things you do on purpose, over
and over, until the groove is worn. A *furrow* is a plough-line deepened by each
repeated pass — the metaphor and the interface are the same thing. Every habit
is one row; every day is one cell; inking a cell blooms the furrow. Fill a week
and it reads as a line cut clean.

It runs entirely on your device. No account, no cloud, no ads, no tracking — the
data never leaves your phone. (See the [privacy model](docs/privacy-model.md);
the shipped Android build carries no `INTERNET` permission at all.)

## What it does

- **Three cadences on one grid.** A habit is a **tick** (done / not-done), a
  **count** (reach N per day — 8 glasses of water), or a **timer** (accumulate
  time — 30 minutes reading). All three live on the same seven-day row.
- **The Franklin thirteen.** An optional starter set of Benjamin Franklin's
  thirteen virtues in his own order, each with its precept, plus a quiet
  "virtue of the week" rotation.
- **Calm by design.** Streaks never turn red, reset silently, and never nag.
  Stats are raw counts, not shame-inducing percentages. There are no punitive
  notifications. See [ADR-0007](docs/adr/0007-no-dark-patterns.md).
- **Six gentle awards**, earned once and kept — a slow confetti and a quiet
  fact line, never an "Achievement Unlocked!" jingle.
- **Ghost mode is the whole product.** Zero identity, zero server contact.

## Try it

- **Web (PWA):** <https://levitatingflyfisher.github.io/Furrow/> — installable,
  works offline.
- **Android (APK):** sideload the build attached to the repo's release tag.

## Quickstart (development)

Encrypted backup is built on two shared packages consumed by **sibling path
dependency** (`../packages/...`, the same convention as `eloEngine`). Clone
them next to Furrow so the paths resolve:

```
packages/
  sanctuary_auth_core/     # github: levitatingflyfisher/sanctuaryAuthCore
  sanctuary_backup_ui/     # github: levitatingflyfisher/sanctuaryBackupUi
Furrow/                    # this repo
```

```bash
git clone https://github.com/levitatingflyfisher/sanctuaryAuthCore packages/sanctuary_auth_core
git clone https://github.com/levitatingflyfisher/sanctuaryBackupUi packages/sanctuary_backup_ui
git clone git@github.com:levitatingflyfisher/Furrow.git
cd Furrow
flutter pub get

# Drift + Riverpod generate *.g.dart files (gitignored) — run after every
# fresh checkout or dependency change, or the build fails on missing imports:
dart run build_runner build --delete-conflicting-outputs

flutter run           # launch on a device / emulator / web
flutter test          # unit, widget, and golden suites
flutter analyze       # static analysis — must be clean
```

Details in [docs/how-to/build-and-run.md](docs/how-to/build-and-run.md); the
PWA + APK release flow in [docs/how-to/ship-pwa-and-apk.md](docs/how-to/ship-pwa-and-apk.md).

## See the docs

Start with the **[Vision](VISION.md)** — the one idea, the design commitments,
and an honest scorecard of what's built versus aspirational. Then the
**[documentation index](docs/README.md)**, organized [Diátaxis](https://diataxis.fr/)-style
(tutorials · how-to · reference · explanation).

Working *in* the code (human or agent)? Read **[AGENTS.md](AGENTS.md)** first.

## Stack

Flutter, Clean Architecture (domain / data / presentation per feature),
[Riverpod](https://riverpod.dev/) for state, [Drift](https://drift.simonbinder.eu/)
over SQLite for local storage, `go_router` for navigation. Ships as both a PWA
and an Android APK from one codebase. The *why* behind each choice lives in
[docs/adr/](docs/adr/).

## License

[MIT](LICENSE). The bundled Lora and Nunito font families are licensed
separately under the [SIL Open Font License 1.1](assets/fonts/OFL.txt).
