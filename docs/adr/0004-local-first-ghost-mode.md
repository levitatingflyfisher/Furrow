# ADR-0004: Local-first, ghost mode, no accounts, no BaaS

- **Status:** Accepted
- **Date:** 2026-07-03

## Context

A habit and daily-virtue log is intimate data: what you're trying to be, and how
you're doing at it. The OpenHearth ethos is that such data belongs to the
household and should never be the price of using the tool. The industry default —
require an account, sync everything to a backend, monetize the graph — is exactly
what erodes trust. Furrow needs a stance it can *prove*, not just promise.

## Decision

**Furrow is local-first with "ghost mode" as the whole product.** All data lives
in an on-device SQLite database ([ADR-0003](0003-drift-over-sqflite.md)); the app
works fully offline with no degraded state. There is **no account** for core use:
the auth layer resolves to `GhostAuthRepository` (zero identity, zero server
contact). Token and Named tiers are deliberately left as unimplemented stubs.
There is **no backend-as-a-service** anywhere. Any future sync must be
**encrypted blobs through a dumb relay** the operator cannot read — never
Firebase/Supabase/Auth0, never plaintext.

## Consequences

- **Buys:** a privacy claim that is *architecturally enforced and checkable* — no
  network code, and the shipped Android build declares no `INTERNET` permission
  (see [privacy model](../privacy-model.md)). No login friction; the app is
  useful in the first second.
- **Costs:** no cross-device sync and no cloud backup today — losing the device
  loses the data (mitigated only by the user-initiated PDF export / share sheet).
  Multi-user households share one ghost profile.
- **Forecloses:** any design that assumes a server of record. Sync, if built, must
  be additive and end-to-end encrypted; it can never become mandatory.

## Alternatives considered

- **Account-required cloud sync (Firebase/Supabase):** rejected — it inverts the
  ownership model and makes the private data readable by an operator.
- **Optional account from day one:** deferred, not adopted — even optional
  accounts pull design gravity toward the server. Ghost-only keeps the core
  honest; a later E2E-encrypted sync tier can be added without compromising it.
- **File-based export as the only durability story:** partially adopted (PDF /
  share exist) but insufficient as a backup strategy; noted as a limitation.
