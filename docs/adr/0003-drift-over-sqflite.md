# ADR-0003: Drift over sqflite for local storage

- **Status:** Accepted
- **Date:** 2026-07-03

## Context

Furrow's data is small but relational: habits, many marks per habit (many *rows
per day* for duration sessions), and earned-once awards. It needs typed queries,
reactive streams to drive the UI, migrations for future schema changes, and — for
[ADR-0005](0005-pwa-and-apk.md) — the *same* storage code to run on both native
SQLite (Android) and WASM SQLite (web). Hand-written SQL over a thin wrapper would
put type errors at runtime and duplicate the web/native plumbing.

## Decision

**Use Drift over SQLite** (`drift` + `drift_flutter`, with `sqlite3_flutter_libs`
native and `sqlite3.wasm` + `drift_worker.js` on web). Tables and the database are
declared in `lib/core/storage/app_database.dart`; DAOs and repositories provide
typed access; the database is `schemaVersion 1` with a clean `onCreate` that
creates tables, seeds the six awards, and adds the `(habit_id, date_day)` index.

## Consequences

- **Buys:** compile-checked queries, reactive `watch` streams that pair naturally
  with Riverpod ([ADR-0002](0002-riverpod-state.md)), a first-class migration
  path, and one storage layer that works native and web. Tests use
  `NativeDatabase.memory()` — no mocking.
- **Costs:** another codegen step (`*.g.dart`, shared with Riverpod's), and a web
  build that must ship the WASM engine and drift worker (both live in `web/`; the
  `DriftWebOptions` in `AppDatabase` points at them, or startup throws).
- **Forecloses:** nothing — future schema changes are ordinary Drift migrations
  (bump `schemaVersion`, add an `onUpgrade` step).

## Alternatives considered

- **sqflite + hand-written SQL:** rejected — untyped queries, no reactive streams,
  no web support without a parallel implementation.
- **Isar / Hive (NoSQL):** rejected — the data is genuinely relational (marks
  reference habits; awards reference habits), and week/streak queries want SQL.
- **Plain `SharedPreferences`/JSON:** kept, but only for small key–value
  preferences (`UserPrefs` mirrors this need in-DB); it cannot express the
  habit/mark relations or their queries.
