# AGENTS.md

## Project overview

Kelivo is an Android-only Flutter application. Android native integration uses Kotlin/Java where needed. Package name is `Kelivo` — imports use `package:Kelivo/...`.

## Architecture

- **Feature-based structure**: `lib/features/<feature>/` with `pages/`, `widgets/`, `models/`, `utils/` subdirectories.
- **Android adaptive layouts**: the project may retain reusable responsive layouts and large-screen UI on Android, but iOS, Windows, Linux desktop and macOS are not build targets. Android-specific code lives under `android/` and Android platform services.
- **State management**: Provider (`lib/core/providers/`).
- **Database**: Drift (`lib/core/database/`). Schema versions tracked in `drift_schemas/`.
- **Localization**: ARB-based (`lib/l10n/`), English template (`app_en.arb`). Run `flutter gen-l10n` after editing ARB files and commit the generated output.


## Phased development contract

Before changing the product architecture, read `phases/README.md`,
`phases/MASTER-DEVELOPMENT-PLAN-AR.md`, and all completed phase records.
Implement only the currently active phase and update its implementation report
and acceptance checklist before moving to the next phase. Preserve the
conversation-first product direction: Kelivo is being evolved into a dynamic
video-production agent, not a traditional manual timeline editor.

Skills, video engines, model providers, tools, libraries and workflows must
remain optional, installable, replaceable and removable. Do not bundle a fixed
video engine, video Skill, production library or provider as a mandatory app
dependency. Never overwrite user-authored Skill contents during migration.

## Pre-commit checklist

Format changed Dart files with `dart format`, including files under `lib/`,
`test/`, `integration_test/`, `dependencies/markstream/lib/`, and
`dependencies/markstream/test/`. For code changes, run static analysis before
committing:

```bash
dart analyze --fatal-infos lib test integration_test
(cd dependencies/markstream && flutter pub get && dart analyze --fatal-infos)
```

For ordinary changes, run only the test files or directories covering the
changed behavior and affected callers, using `flutter test <test paths>`.
If `markstream` is affected, also run its relevant tests from
`dependencies/markstream`; root-package checks do not cover this path package.

Run the full test suites locally only when merging a major feature, such as a
cross-feature integration or broad architectural change:

```bash
flutter test
(cd dependencies/markstream && flutter pub get && flutter test)
```

All required checks must pass. Documentation-only changes do not require Dart
analysis or Flutter tests. The currently checked-in GitHub workflow is
`.github/workflows/android-build.yml`; it runs Android-only/release audits,
Arabic ARB parity and localization generation, then builds the ARM64 APK. It
does not run host-side Flutter tests because native-asset hooks can select the
Linux host backend rather than the Android target. Run focused Flutter tests
locally in an environment that includes the native dependencies required by
the packages under test.

## Benchmarks are not tests

`test/perf/*_bench.dart` print timings and contain no `expect()`, so they cannot
fail. They are named out of the default `_test.dart` glob and so are skipped by
`flutter test`. Run one explicitly:

```bash
flutter test test/perf/timeline_scroll_bench.dart
```

## UI guidelines

- **Use app-defined widgets** from `lib/shared/widgets/` and `lib/shared/dialogs/` instead of raw Flutter/Material widgets wherever an equivalent exists (e.g. `SectionCard`, `CustomBottomSheet`, `IosFormTextField`, `IosCheckbox`, `InteractiveDrawer`).
- **BottomSheet**: both Flutter's built-in bottom sheet and `CustomBottomSheet` are fine on mobile. Never use any bottom sheet on desktop — use a dialog or another interaction pattern instead.
- **Icons**: use `lucide_icons_flutter`, not `Icons.*` from Material.
- **Animations**: use `flutter_animate` / `animations` for motion.
- When building a new page, create separate desktop and mobile layouts unless the page is trivially simple. Wire them together via `ResponsiveHelper`.

## Code style

- Remove obsolete implementation paths when they are no longer needed, but never delete or overwrite user-authored data during migrations. Prefer a safe data-preserving migration over a compatibility layer that keeps obsolete runtime code alive.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.

## Local dependencies

Several packages live under `dependencies/` and are referenced by path in `pubspec.yaml` (e.g. `markstream`, `mcp_client`, `flutter_tts`, `flutter_math_fork`, `downsize`). The analyzer excludes `dependencies/flutter_math_fork/**` and `dependencies/flutter_tts/**`.

## Useful commands

```bash
flutter pub get                             # install dependencies
flutter gen-l10n                            # regenerate l10n files
dart run build_runner build                 # regenerate Drift code
```
