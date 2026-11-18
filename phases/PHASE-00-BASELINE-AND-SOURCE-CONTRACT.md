# PHASE 0 — Baseline and Source Contract

**Status:** Baseline established from the Android-only source archive and user-confirmed successful APK installation.

## Baseline evidence

- Source starting point: the cleaned Android-only Kelivo project supplied in `KELIVO-ANDROID-ONLY-CLEAN.zip`.
- The user confirmed that the Android ARM64 GitHub Actions build completed successfully and the application opened on the device before Phase 1 changes.
- Android is the only target platform retained in this project.
- Flutter/Dart remain the application layer; Kotlin/Android native code remains available for Android-specific capabilities.
- The Android build workflow is `.github/workflows/android-build.yml`.
- The PR quality workflow is `.github/workflows/pr-check.yml`.
- A Git commit hash, APK SHA-256 and exact runner artifact were not supplied with the source archive; these values must be captured from the user's successful GitHub run before release tagging.

## Preserved core capabilities

- Chat, assistants, conversations and model-provider configuration.
- Tool/function calling and tool approval pathways.
- Skills storage and existing import surfaces.
- Workspace runtime, file access and PRoot/Linux environment support.
- MCP provider and its existing transports.
- SQLite/Drift persistence and backup/restore behavior.
- Android native integration and ARM64 build configuration.

## Source contract

1. Do not replace Kelivo's existing application architecture or restart the project from a blank template.
2. No video-specific engine, provider, skill or production package is bundled as a mandatory dependency.
3. Video creation must remain conversation-first. A traditional timeline editor is not the product target.
4. The platform must allow the user to select code-generated, model-generated or hybrid video creation.
5. Skills, engines, tools, providers, workflows and assets are optional extension types.
6. Cross-reinstall preservation of local development data is not required. Within an active install, a Skill update must still create a rollback snapshot before replacing its current files.
7. Secrets and credentials are not stored in extension metadata or Skill files.
8. Every delivered source archive has one top-level `KELIVO/` folder and preserves source-relative paths.

## Baseline acceptance

- [x] User-confirmed Android ARM64 APK build and successful launch on the pre-Phase-1 source.
- [x] Android-only target tree established.
- [ ] Capture immutable successful build commit and APK SHA-256 from GitHub before release tagging.
- [ ] Re-run baseline regression suite after Phase 1 changes.
