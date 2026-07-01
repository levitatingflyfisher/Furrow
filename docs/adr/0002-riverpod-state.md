# ADR-0002: Riverpod (with codegen) for state

- **Status:** Accepted
- **Date:** 2026-07-03

## Context

The UI must react to on-device data without manual refresh: mark a habit and its
cell, the streak, and any newly-earned award should update on their own. Drift
exposes reactive `watch` streams; the app needs a state layer that composes those
streams, injects dependencies (database, repositories, `SharedPreferences`), and
is testable with overrides.

## Decision

**Use Riverpod for all app state**, with `riverpod_generator` codegen for
providers. Widgets `watch` providers; providers wrap Drift streams and repository
calls. Dependencies are injected via provider overrides (e.g.
`sharedPreferencesProvider.overrideWithValue(...)` at app start, in-memory DB in
tests).

## Consequences

- **Buys:** compile-time-safe dependency injection, painless test overrides, and
  a clean bridge from Drift streams to rebuilding widgets. No `BuildContext`
  needed to read state.
- **Costs:** a codegen step — `*.g.dart` files are gitignored and must be
  regenerated (`dart run build_runner build --delete-conflicting-outputs`) after
  a fresh checkout or a provider change, or the build fails on missing imports.
- **Forecloses:** little; Riverpod is incremental and coexists with plain
  `ValueNotifier`/`ChangeNotifier` where a provider would be overkill.

## Alternatives considered

- **Provider (the package):** rejected — Riverpod is its successor, without the
  `BuildContext` coupling and with better testability.
- **BLoC:** rejected — heavier ceremony than a single-user CRUD-plus-derivations
  app needs; the derivations are already pure functions in the domain layer.
- **Raw `setState` + manual DB reads:** rejected — loses the reactive stream
  wiring that makes "mark a habit, everything updates" free.
