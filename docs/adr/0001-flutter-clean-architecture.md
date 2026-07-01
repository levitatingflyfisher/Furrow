# ADR-0001: Flutter + Clean Architecture, feature-first

- **Status:** Accepted
- **Date:** 2026-07-03

## Context

Furrow was forked from Sundial, a sibling OpenHearth app, and inherits its stack.
The shared OpenHearth commitment is that domestic software should *last*: it must
run on the phones families actually own, be cheap to reason about years later,
and keep its core rules testable without a device or a running app. That rules
out a UI where business logic is tangled into widgets.

## Decision

**Build on Flutter with a feature-first Clean Architecture.** Each feature (e.g.
`habits`, `settings`, `onboarding`) is a directory split into three layers:

- `domain/` — entities and **pure functions** (no Flutter, no database), plus
  abstract repository interfaces.
- `data/` — Drift DAOs and concrete repository implementations.
- `presentation/` — screens, widgets, and Riverpod providers.

Dependencies point **inward**: presentation depends on data depends on domain;
domain depends on nothing downward.

## Consequences

- **Buys:** the load-bearing rules (streaks, completion, awards, virtue-of-week)
  are plain Dart in `habit_logic.dart` / `awards.dart` and are unit-tested with
  no widget or DB harness. One codebase targets Android and web
  ([ADR-0005](0005-pwa-and-apk.md)).
- **Costs:** more files and indirection than a "logic in the widget" app; a
  contributor must learn where a change belongs before making it.
- **Forecloses:** nothing structural. The layering is a convention, not a
  framework lock-in.

## Alternatives considered

- **Logic-in-widgets (setState everywhere):** rejected — the streak/award math is
  exactly the part most worth testing, and it would become untestable.
- **A different cross-platform toolkit (React Native, KMP):** rejected — Flutter
  is the established OpenHearth toolkit; a lone divergent stack would fragment the
  shared knowledge and tooling for no app-specific gain.
- **Native Android + separate web app:** rejected — two codebases to maintain for
  a small single-user app is not worth the platform-fidelity gain here.
