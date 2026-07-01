# Reference: feature status

What's shipped, what's deferred, at a glance, as of **v0.1.0**. The honest
narrative version is the [Vision scorecard](../VISION.md#honest-scorecard--built-vs-aspirational);
the caveats are in [limitations](../limitations.md).

## Shipped (real, tested)

| Area | Status |
|---|---|
| Three cadences (tick / count / timer) end-to-end | ✅ |
| FurrowRow Today grid + partial-bloom cells | ✅ (golden-tested, phone/tablet, textScale 1×–3×) |
| Inline logging: tap = today, long-press = fix past *tick* | ✅ |
| `LogTimeSheet` (chips +5/+15/+30, exact stepper, live stopwatch) | ✅ |
| Pure domain logic (value, progress, streak, best, clean-week) | ✅ (unit-tested) |
| Franklin 13-virtue seed (opt-in) + virtue-of-the-week | ✅ |
| Six awards (hardcoded checks) + gentle confetti | ✅ |
| Habit Detail (calm streak + heatmap), Stats (raw counts) | ✅ |
| Onboarding with starter templates | ✅ |
| Flow / Rich Today modes | ✅ |
| Ghost mode (local-only, no account) | ✅ |
| Local storage (Drift/SQLite), schemaVersion 1 | ✅ |
| Android APK + installable web PWA, fully offline | ✅ |
| Bundled fonts (Lora + Nunito), no CDN fetch | ✅ (guarded by a test) |
| Concurrent-tap-safe mark writes | ✅ (regression-tested) |
| Encrypted backup/restore (`.ohbk`, seed phrase) | ✅ ([ADR-0008](../adr/0008-encrypted-backup-seed-phrase.md)) |

## Deferred (schema- or key-ready, not wired)

| Area | Status |
|---|---|
| `weeklyCount` schedule + week-grained streak | ⏳ columns exist; UI treats as "any day" |
| Per-virtue precept editing | ⏳ `UserPrefs` key exists; no editor |
| General award-criterion engine | ⏳ v1 hardcodes 6 checks |
| Inline past-edit for count / duration | ⏳ detail-screen only for now |
| Home-screen widget metric rework | ⏳ widget exists, depth deferred |

## Not built (aspirational)

| Area | Status |
|---|---|
| Sync / multi-device / cloud backup | ❌ by design (local-only — encrypted *manual* backup exists, see above) |
| Multi-user / profiles | ❌ single-user by design |
| Token / Named auth tiers | ❌ stubs throw `UnimplementedError` |
| Reminders / nudges | ❌ by design ([ADR-0007](../adr/0007-no-dark-patterns.md)) |
| iOS / desktop builds | ❌ Flutter-capable, not built |

Legend: ✅ shipped · ⏳ deferred (groundwork present) · ❌ not built (often by
design).
