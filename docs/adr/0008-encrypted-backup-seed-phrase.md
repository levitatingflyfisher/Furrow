# ADR-0008: Encrypted backup via a seed phrase, on the shared sanctuary packages

- **Status:** Accepted
- **Date:** 2026-07-12

## Context

Furrow is local-only by design (ADR-0004): there is no server, no account, and
no cloud copy. Until now that also meant *no backup at all* — losing or
wiping the device loses every habit, mark, and earned award, with nothing to
restore from (see [limitations](../limitations.md)). Local-only should not
mean "your data is one dropped phone away from gone."

Auth/crypto is also security-sensitive code that should be written and
audited once and shared across OpenHearth apps, not re-implemented per app —
`sanctuary_auth_core` (the crypto primitives) and `sanctuary_backup_ui` (the
generic backup controller + widgets) already exist for this reason.

## Decision

Add an **encrypted `.ohbk` backup** to Settings, built on the shared
`sanctuary_auth_core` + `sanctuary_backup_ui` packages (consumed as sibling
path dependencies — see the [README](../../README.md#quickstart-development)).
There is no server and no account: the seed phrase is a recovery key, not a
login.

- The **key** is derived from a 12-word seed phrase (BIP39 + HKDF), isolated
  to Furrow via its own `appDomain` (`'furrow'`) so its key material never
  overlaps another OpenHearth app sharing a household seed. The user proves
  they wrote the phrase down by re-entering it before export becomes
  available — turning a UX assertion into a cryptographic check.
- The payload is encrypted with **ChaCha20-Poly1305** (AEAD), scoped by the
  `furrow-backup/v1` AAD context, and framed in the OHBK wire format.
- **`FurrowBackupSerializer` is a fresh JSON envelope** (`{app,
  schemaVersion, exportedAt, tables}`) — Furrow had no pre-existing export
  code to wrap. Restore rejects a payload whose `app` field isn't `"furrow"`
  or whose `schemaVersion` is newer than the running app understands, before
  the bytes are ever handed to the database — defense in depth behind the
  AEAD context, which already binds a blob to this one app.
- **Restore is destructive and transactional**: Habits, HabitMarks, and
  UserPrefs are wiped and re-inserted inside one Drift transaction. The
  six-award badge catalog is code-defined (`AppDatabase._seedAwards`), not
  per-user data — restore never deletes or reinserts it, only resets and
  re-applies *earned* status by id, so a backup made on an older app version
  can't silently drop a badge type added since.
- **Presentation is Furrow's own** — a `ListTile`/`LucideIcons` section
  (`BackupSection`) rather than the package's generic `BackupSettingsSection`
  (built on Material `Icons.*`), which would visually clash with the rest of
  the Settings screen. Only the layout is app-specific; setup, export,
  restore, and reset all delegate to the package's shared `BackupController`,
  `SeedPhraseModal`, and `PhraseEntryDialog` — no crypto or state machine is
  reinvented.

## Consequences

- **Buys:** a real "please keep this safe" backup and restore path, with
  zero server and zero plaintext egress; a shared, auditable crypto module;
  device loss no longer means the data is unrecoverable if a backup was
  made.
- **Costs:** the seed phrase is unrecoverable if lost — there is no reset
  email, by design. The destructive-replace restore requires an explicit
  confirm dialog stating the consequence in full ("This cannot be undone").
- **Forecloses:** server-side key escrow or account-based recovery.
  Recovery is the user's responsibility, mediated only by the seed phrase —
  the honest cost of local-only (see [privacy model](../privacy-model.md)).
  This is still **not sync**: nothing moves automatically between devices;
  the user carries the `.ohbk` file themselves.

## Alternatives considered

- **Drop in `sanctuary_backup_ui`'s `BackupSettingsSection` wholesale:**
  rejected for the visual clash noted above (Material `Icons.*` amid
  LucideIcons everywhere else) — the same choice Sundial's wiring made for
  the identical reason.
- **A second bespoke serializer format, independent of the package's
  `BackupSerializer` interface:** rejected — there was no existing export
  code worth preserving, and inventing a second envelope shape would only
  add a maintenance burden the shared interface already avoids.
- **No `app` field, relying on the AEAD context alone:** rejected per
  SANCTUARY-BRIEF §2.8 — the context makes cross-app decryption fail, but a
  hand-edited or corrupted payload that happens to decrypt under the right
  key deserves its own explicit rejection, not a downstream crash.
