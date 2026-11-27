# Kelivo — Android Edition

This repository contains the Android edition of Kelivo. The production APK targets ARM64 (`arm64-v8a`) only. Linux userland tools run inside the Android PRoot workspace; they are not separate desktop targets.

## Current development state

- Active phase: **Phase 14E — Universal Tool Registry, Toolsets & Deferred Tool Exposure**.
- Phase 14A–14D are accepted through their dedicated CI gates (#162, #164, #199 and #204).
- Phase 14E.1 targeted tests passed in CI #206; Phase 14E.2 turn-scoped conversation integration tests passed in CI #208. Phase 14E as a whole remains in progress.
- Phase 14F–14H have not started.
- Phase 13Q backend/lifecycle and Phase 14D real STDIO integration are tested; Phase 13R CI lifecycle regressions pass, with real-device lifecycle acceptance still pending.

## Build and CI

The current Android ARM64 workflow audits Android-only sources and release hardening, resolves Flutter dependencies, validates Arabic localization parity, generates localizations, analyzes `lib/`, `test/` and `integration_test/`, runs Environment lifecycle, Phase 14A, 14B and 14E.2 tests, Gemini/provider OAuth regressions, Phase 14C.4 Remote Skills, Phase 13Q/14D real STDIO integration, five vendored package suites, Android JVM/Robolectric and Phase 13P Android emulator E2E. It then builds the ARM64 APK, validates the archive ABI, calculates SHA-256, uploads the APK and publishes a separate Markdown report.

**Test-scope accuracy:** this workflow does not run the complete root Flutter unit/widget suite or every historical focused suite for Phases 13E–13O. Static analysis of those directories is not evidence that those tests ran.

Toolchain: Flutter 3.47.6, Java 21, Android NDK 28.2.13676358, CMake 3.22.1. Without `android/key.properties`, the Release APK uses the debug signing key; it is suitable for installation/testing, not public Play Store signing.

## Latest verified CI baseline

Run [#208](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283) completed successfully on `main` commit `77736b783d55752a35a3aeb3b66b6b6dce7e87f1` on 27 November 2026.

- Flutter Analyze, Environment lifecycle, Phase 14A/14B/14E.2, provider schema/OAuth, Phase 14C.4, Phase 13Q/14D real STDIO and five local package suites passed.
- Android JVM/Robolectric and Phase 13P Android Emulator E2E passed.
- ARM64 APK build, ABI verification, SHA-256, artifact upload and report publication passed.
- APK: 41,943,583 bytes; `arm64-v8a` only.
- SHA-256: `29fa1b9db0223dd0b9c6d8f170af3b86f6d44f2f5dd88a992843bd09f907f6fa`.
- APK Artifact ID: `15167472926`; [download APK](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167472926).
- Build report Artifact ID: `15167378117`; [build report](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167378117).
- Raw diagnostics Artifact ID: `15167717401`; [raw logs](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167717401).

See [phases/README.md](phases/README.md) for the phase index and [the Phase 14E status report](phases/PHASE-14E-IMPLEMENTATION-STATUS-AR.md) for the remaining acceptance gates.

## Platform and security boundaries

The supported app target in this source snapshot is Android. iOS, Windows, macOS, desktop Linux and Web are not supported release targets. PRoot is Linux userland, not a kernel sandbox: the active RootFS remains shared/writable and guest network access is not fully restricted. Android Emulator success does not prove Force Stop recovery on a user's device.
