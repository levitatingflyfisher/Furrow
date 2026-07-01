# How to build & run Furrow

Task-oriented. Assumes a working [Flutter](https://docs.flutter.dev/get-started/install)
toolchain (`flutter --version` succeeds).

## First run

```bash
git clone git@github.com:levitatingflyfisher/Furrow.git
cd Furrow
flutter pub get
```

**Generate the codegen files before your first build.** Drift and Riverpod emit
`*.g.dart` files, which are **gitignored**. Run this after every fresh checkout or
dependency change:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Skip it and `flutter build`/`flutter run` fails with "No such file or directory"
errors on `*.g.dart` imports. To keep codegen running as you edit, use
`dart run build_runner watch --delete-conflicting-outputs` in a side terminal.

## Run it

```bash
flutter run                 # pick a connected device / emulator
flutter run -d chrome       # run as a web app
```

On first launch with an empty `UserPrefs` table, the router redirects to
onboarding; after that it opens to the Today grid.

## Test & analyze

```bash
flutter test                # unit + widget + golden suites under test/
flutter analyze             # static analysis — must be clean
flutter test test/features  # a subdirectory, when iterating
```

- Tests use an **in-memory** SQLite database (`NativeDatabase.memory()`) — no
  mocking, no device needed.
- **Golden tests** (`test/visual/`) are sensitive to font rasterisation and are
  tagged out of CI. When you intentionally change the grid's appearance,
  regenerate them:
  ```bash
  flutter test --update-goldens test/visual/
  ```
- The project uses `package:flutter_lints` with no overrides. Don't disable a lint
  rule without a justification in the PR.

## Build artifacts

```bash
flutter build apk --debug   # Android debug APK → build/app/outputs/flutter-apk/
flutter build web           # Web bundle → build/web/
```

For the release/deploy flow (gh-pages PWA + tagged APK), see
[ship-pwa-and-apk.md](ship-pwa-and-apk.md).

## Android build notes

- Java 25 is supported; the Gradle wrapper version is pinned in
  `android/gradle/wrapper/gradle-wrapper.properties`.
- Core-library desugaring is enabled in `android/app/build.gradle.kts`.
