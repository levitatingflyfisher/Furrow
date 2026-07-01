# ADR-0005: Ship both a PWA and an APK from one codebase

- **Status:** Accepted
- **Date:** 2026-07-03

## Context

Families should be able to try Furrow with zero commitment (a link, no install,
no store account) *and* keep it as a real app on the phone. App-store
distribution alone adds friction and a gatekeeper; web-only gives up the
home-screen presence and Android niceties (the duration-timer foreground
service, an app icon). Flutter can target both from one codebase, so the choice
is whether to actually maintain both targets.

## Decision

**Ship both surfaces from the single Flutter codebase:** an installable **PWA**
deployed to GitHub Pages, and a sideloadable **Android APK** built from a release
tag. Drift's web support carries the storage layer to WASM SQLite; the web shell
(`web/index.html`) bakes in a boot spinner, a service-worker self-heal (reload
once when a new worker takes over so a returning visitor never sees a stale
shell), and `navigator.storage.persist()` to resist eviction of local data.

## Consequences

- **Buys:** frictionless "try it in the browser" *and* a durable installed app,
  with one set of features and tests. Local-first holds on both (WASM SQLite in
  the browser, native SQLite on device).
- **Costs:** two deploy paths to keep working (a manual gh-pages web deploy gated
  on `build/web/main.dart.js`, plus a tag-triggered Android release), the WASM
  engine + drift worker must be shipped in `web/`, and browser storage is
  evictable — hence the `persist()` call and the self-heal. Fonts are **bundled**
  (Lora + Nunito) rather than fetched, so the web build makes no runtime request
  to a font CDN.
- **Forecloses:** nothing; iOS/desktop remain latent Flutter targets, just not
  built today.

## Alternatives considered

- **Web only:** rejected — loses home-screen presence, the app icon, and the
  Android foreground-service timer.
- **APK / store only:** rejected — adds install friction and a gatekeeper for a
  free FLOSS tool that a browser link could deliver instantly.
- **Fetching web fonts from a CDN:** rejected — a runtime network request would
  break the "nothing leaves the device" claim; fonts are bundled instead.
