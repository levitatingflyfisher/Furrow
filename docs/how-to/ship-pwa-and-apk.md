# How to ship the PWA + APK

Furrow ships two surfaces from one codebase ([ADR-0005](../adr/0005-pwa-and-apk.md)):
an installable web PWA on GitHub Pages, and a sideloadable Android APK from a
release tag. This is the release flow.

## Before you ship

```bash
flutter analyze          # clean
flutter test             # green (goldens are excluded from CI; run them locally if UI changed)
dart run build_runner build --delete-conflicting-outputs
```

Bump the version in `pubspec.yaml` (`version: X.Y.Z+build`).

## Web (PWA) → GitHub Pages

```bash
flutter build web --release --base-href /Furrow/
```

- The `--base-href /Furrow/` matches the Pages sub-path
  (`levitatingflyfisher.github.io/Furrow/`).
- **Gate the deploy on `build/web/main.dart.js` existing** — a partial build that
  produces `index.html` without the app bundle will publish a blank shell.
- The source `web/index.html` already bakes in the pieces a robust PWA needs — a
  boot spinner, a service-worker **self-heal** (reload once when a new worker
  takes over, so a returning visitor never sees a stale shell), and
  `navigator.storage.persist()` to resist eviction of local data. Preserve these
  if you regenerate the shell.
- Publish `build/web/` to the Pages branch/target for this repo.

Because storage in a browser is evictable, remind users that the **installed APK**
is the durable option for long-term data (see [limitations](../limitations.md)).

## Android (APK) → release tag

The Android release is driven by an in-repo GitHub Actions workflow
(`.github/workflows/release.yml`) triggered by a `v*.*.*` tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow builds the APK (split-per-ABI) and attaches it to the release. Users
sideload it; there is no app-store account required.

## Landing card

Furrow has a card on the OpenHearth landing site
(`levitatingflyfisher.github.io`) offering both the PWA link and the sideload APK.
Keep that card's links pointing at the current Pages URL and the latest release.

## Sanity checks after a deploy

- Open the PWA in a fresh/incognito browser — it should show the boot spinner,
  then the Today grid (or onboarding on first run), and work with the network cut.
- Confirm the shipped APK requests **no `INTERNET` permission** (see
  [privacy model](../privacy-model.md)) — a regression here breaks the core
  promise.
