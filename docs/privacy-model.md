# Privacy model

The short version: **nothing leaves your device.** Furrow has no accounts, no
network layer, no analytics, and no cloud. This page says exactly what that means
and — more importantly — how you can *check* it rather than take it on faith.

## What Furrow stores, and where

| Data | Where it lives |
|---|---|
| Habits, marks (including timed sessions), earned awards | On-device SQLite database (via Drift), in the app's private storage |
| Preferences (theme, Flow/Rich mode, virtue-seed flag) | On-device `SharedPreferences` / the `UserPrefs` table |
| Encrypted-backup recovery phrase (if you set one up) | On-device secure storage (OS keychain), never transmitted — see [ADR-0008](adr/0008-encrypted-backup-seed-phrase.md) |

That is the entire footprint. There is no server-side copy because there is no
server.

## What leaves the device

**Nothing, automatically.** There is no telemetry, no crash reporting to a third
party, no ad SDK, no sync. The only ways any data moves off the device are ones
*you* explicitly trigger:

- **PDF export / system share sheet.** If you export or share, the file goes
  wherever you send it — that is your action and your choice, handled by the OS
  share mechanism, not a Furrow backend.
- **Encrypted backup (`.ohbk`).** Settings → Encrypted Backup lets you export
  every habit, mark, and earned award as a file encrypted (ChaCha20-Poly1305)
  under a 12-word recovery phrase you generate and keep yourself — see
  [ADR-0008](adr/0008-encrypted-backup-seed-phrase.md). The phrase never
  leaves the device and there is no server that holds a copy of it or the
  file; lose the phrase and the backup is unreadable, by design. This is a
  backup you carry yourself, not sync — nothing moves automatically between
  devices.

The one notification Furrow can post is the transient Android **foreground-service
notice that keeps a running duration timer alive** — it is local to the device and
is not an engagement nudge. See [ADR-0007](adr/0007-no-dark-patterns.md).

## How to verify it yourself

These claims are meant to be checkable, not trusted:

1. **No network code.** Grep the app source for any egress and find none:
   ```bash
   grep -rniE 'http[s]?://|HttpClient|package:http|dio|socket|firebase|supabase|analytics' lib/
   ```
   (Matches are limited to doc/comment URLs, not calls.)
2. **No `INTERNET` permission in the shipped app.** Furrow's own source manifest
   (`android/app/src/main/AndroidManifest.xml`) requests only `POST_NOTIFICATIONS`,
   `VIBRATE`, and `FOREGROUND_SERVICE_MEDIA_PLAYBACK`. What actually ships, though,
   is the *merged* manifest (Furrow's + its plugins'), so check that one — it is
   the source of truth:
   ```bash
   flutter build apk --release
   grep -i INTERNET build/app/intermediates/packaged_manifests/release/*/*/AndroidManifest.xml
   # or, on the built APK:
   aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
   ```
   The merged manifest declares **no `INTERNET` permission** — so the app cannot
   open a socket or transmit anything, full stop. (An `INTERNET` line exists only
   in the *debug* / *profile* source manifests, which Flutter merges for local
   development and which never ship.) A handful of permissions *are* pulled in by
   plugins — `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE`,
   `RECEIVE_BOOT_COMPLETED`, `BIND_JOB_SERVICE`, `BIND_REMOTEVIEWS` — and none of
   them permit network I/O. `ACCESS_NETWORK_STATE` only lets code read *whether* a
   network exists (a transitive plugin dependency); with no `INTERNET`, the app
   still cannot send or receive a single byte.
3. **Fonts are bundled, not fetched.** Lora and Nunito ship in `assets/fonts/` and
   are declared in `pubspec.yaml`, so even the web build makes no runtime request
   to a font CDN. An `offline_fonts_test` guards this.
4. **Airplane mode.** Turn off all connectivity; every feature still works,
   because offline *is* the mode.

## Threat model (what this does and doesn't protect against)

- **Protects against:** operator data access (there is no operator), account
  compromise (there is no account), tracking / profiling / data sale
  (architecturally impossible without egress).
- **Does not protect against:** anyone with access to the unlocked device — the
  database is app-private but not separately encrypted at rest; device-level
  lock/encryption is your protection. Nor does it protect data you *choose* to
  export and send somewhere.
- **Backup is your responsibility.** Because there is no cloud copy, losing or
  wiping the device loses the data unless you made your own copy first — a
  PDF export, or the encrypted `.ohbk` backup (ADR-0008), which you must
  store somewhere yourself (there is no auto-sync). This is the honest cost
  of local-only — see [limitations](limitations.md) and
  [ADR-0004](adr/0004-local-first-ghost-mode.md).

## If sync is ever added

It must be **opt-in** and travel as **encrypted blobs through a dumb relay** the
operator cannot read — never a backend-as-a-service, never plaintext. Ghost mode
must remain complete and default. This is a hard invariant, not a preference.
