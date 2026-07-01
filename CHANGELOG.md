# Changelog

All notable changes to Furrow will be documented in this file.

## [0.2.0] - 2026-07-27 — the Franklin-faithful loop

Franklin's actual method was one focus virtue per week and a single
evening review — he never ticked thirteen boxes all day. This release
turns the app the right way around: the daily interaction is one
thumb-sized moment, and the inked grid becomes the beautiful output.

### Added
- **The evening review**: one pass down the day's rows with big controls
  (Done/Undo, count steppers, +5/+15/+30 time chips). Day chips reach
  back a week — catching up is normal, not a correction. No nags, no
  badges; skipping writes nothing.
- **The focus virtue leads**: tap the weekly banner to choose this
  week's focus (or follow the classic 13-week rotation); its row leads
  the grid.
- **Full CRUD, no dead ends**: delete any history mark (fat-fingers are
  no longer forever), Clear history for a fresh start without
  re-planting, archive ("Rest this habit") with a Resting list in
  Settings to bring habits back.

### Changed
- **Every grid cell is a thumb target**: the row split into two lines —
  name above (navigates), seven full-width day cells below (log). Cells
  grew from 26px to ≥40dp columns at 44dp height; a near-miss now logs
  instead of navigating away.

## [Unreleased]

### Added
- `assets/fonts/OFL.txt`: the SIL Open Font License 1.1 text with the
  Lora and Nunito copyright notices (taken from the fonts' own
  metadata) now ships alongside the bundled faces, as the OFL requires;
  referenced from the README's License section.
- Snapshot vault ("Previous backups" in Settings): every encrypted
  export and every restore leaves a stamped on-device snapshot
  (keep-10, pinnable) you can restore, pin or delete.
- Mandatory pre-restore snapshot: a restore refuses to run unless the
  current data was snapshotted (and the snapshot verified) first —
  restoring is now reversible.
- Preview before restore: the confirm dialog shows the backup's age and
  per-table row counts next to what's on the device now.
- Encrypted exports verify themselves by read-back before reporting
  success, and the backup envelope now carries a `createdAt` stamp
  (older backups still restore; older app versions still read new
  backups — every legacy key is kept).
- "Export as plain JSON" in Settings: an unencrypted copy of all your
  data, honestly labeled — readable by any program, no key needed.
- Silent freshness snapshot on app open when the newest one is older
  than 7 days (only when encrypted backup is set up).
- `DateTime.dateOnly`, `DateTime.startOfWeek` and a DST-safe
  `daysBetweenDates` (plus `minutesToLabel`) in the shared datetime
  extensions, synced verbatim from Bulwark's fork-lineage copy.
- Push-triggered CI (`ci.yml`, fleet idiom): sibling path-dep clones,
  `pub get`, code generation, `flutter analyze`, `flutter test` on
  every push and pull request, pinned to Flutter 3.38.7.
- Fleet conformance suite (`oh_fleet_conformance` dev dependency):
  Furrow's posture — tokens style tier, POST_NOTIFICATIONS + VIBRATE
  (and structurally NO INTERNET), size budgets in `budgets.json`,
  canonical test harness — is now enforced by tests, not prose.

### Fixed
- The clean-week award no longer permanently disqualifies a habit
  created ON the Monday of an otherwise fully-kept week: eligibility now
  compares creation *day* to the week's Monday, not the creation instant
  to Monday midnight.
- Today's week strip derives "today" from `package:clock` instead of
  `DateTime.now()`, so golden tests pin the date — the Today goldens no
  longer fail on every calendar day but the one they were generated on.
- Every remaining `DateTime.now()` in the app now goes through
  `package:clock` too (time logging, streaks in Garden and Habit Detail,
  the award scan and its earned-at stamp, record timestamps, backup
  stamps), closing the midnight tear where the Today grid could show one
  day while the flows it triggers wrote and read another.
- Golden tests load Furrow's bundled fonts (canonical fleet
  `flutter_test_config.dart`): headings, Lucide icons and button labels
  render truly in golden PNGs instead of placeholder black boxes.

### Removed
- Unused `pdf`, `printing` and `share_plus` dependencies (Sundial fork
  inheritance Furrow never used — zero imports).
- The unexercised `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission and the
  dead `TimerForegroundService` / `MediaActionReceiver` declarations:
  Furrow's Dart never opens the fork-inherited media-session channel
  (duration habits log time after the fact). The permission surface is
  now exactly POST_NOTIFICATIONS + VIBRATE — and still no INTERNET.

### Fixed
- Release CI clones the `ohStyle` sibling it has needed since the
  design-package adoption (a tag build would have failed `pub get`),
  plus the new `ohFleetConformance` test dependency.
- Streaks, the weekly virtue rotation, the clean-week award scan and
  the Today week strip now use calendar-day arithmetic instead of
  Duration math, so a daylight-saving transition can no longer skip a
  day (breaking an unbroken streak), bridge a real gap, or scan the
  wrong week.
- `startOfWeek` itself now uses calendar arithmetic too (it still
  subtracted a Duration from local midnight): in timezones whose DST
  transition falls at midnight mid-week it returned Monday 01:00/23:00
  instead of Monday midnight, skewing everything keyed on the week
  start.

### Changed
- Upgraded `sanctuary_backup_ui` to 0.2.0 (the backup-retention
  release behind everything above).
- Adopted the shared `openhearth_design` package (tier-T, zero visual
  change): the text ladder now comes from
  `OhTypography.materialTextTheme` (byte-identical to the old
  hand-rolled block, locked by a test) and canonical color values
  (sage/slate/terracotta/amber, linen 50/900, the dark surface base)
  are referenced as `OhColors` tokens. Furrow's signature ochre stays
  app-local.
