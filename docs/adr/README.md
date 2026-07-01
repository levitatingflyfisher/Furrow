# Architecture Decision Records

An ADR captures **one architectural decision**: the context that forced it, the
choice made, and the consequences we accepted. They are immutable once accepted —
if a decision is revisited, add a *new* ADR that supersedes the old one (and mark
the old one `Superseded by ADR-NNNN`) rather than editing history.

Read these when you're about to change something load-bearing and want to know
whether you're fixing a mistake or unknowingly reopening a settled trade-off.

## Index

| # | Decision | Status |
|---|---|---|
| [0001](0001-flutter-clean-architecture.md) | Flutter + Clean Architecture, feature-first | Accepted |
| [0002](0002-riverpod-state.md) | Riverpod (with codegen) for state | Accepted |
| [0003](0003-drift-over-sqflite.md) | Drift over sqflite for local storage | Accepted |
| [0004](0004-local-first-ghost-mode.md) | Local-first, ghost mode, no accounts, no BaaS | Accepted |
| [0005](0005-pwa-and-apk.md) | Ship both a PWA and an APK from one codebase | Accepted |
| [0006](0006-three-cadences-one-table.md) | Three cadences on one `Habits` table | Accepted |
| [0007](0007-no-dark-patterns.md) | No streaks-as-dark-patterns | Accepted |
| [0008](0008-encrypted-backup-seed-phrase.md) | Encrypted backup via a seed phrase, on the shared sanctuary packages | Accepted |

## Writing a new one

Copy [`0000-template.md`](0000-template.md) to the next number, fill it in, add a
row above. Keep it to ~one screen — an ADR that needs scrolling is two ADRs.
