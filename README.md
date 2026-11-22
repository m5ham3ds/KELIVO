# Kelivo — Android Edition

This repository contains the Android edition of Kelivo. The production APK targets ARM64 (arm64-v8a) only. Linux userland tools run inside the Android PRoot workspace; they are not separate desktop targets.

## Build and CI
The Android ARM64 workflow audits Android-only sources and release hardening, resolves Flutter dependencies, validates Arabic localization parity, generates localizations, analyzes lib/, test/, and integration_test/, runs the Phase 13Q MCP configuration parser tests, tests five vendored packages, runs Android JVM/Robolectric and four Android emulator integration tests on main (including Phase 13P), then builds and uploads the ARM64 APK and SHA-256 checksum.

**Test-scope accuracy:** this workflow does not run the complete root Flutter unit/widget suite or the historical focused suites for Phases 13E–13O. Static analysis of their directories is not a substitute for executing those tests.

Toolchain: Flutter 3.47.6, Java 21, Android NDK 28.2.13676358, CMake 3.22.1. Without android/key.properties the Release APK uses the debug signing key; it is suitable for installation/testing, not public Play Store release signing.

## Latest verified CI baseline
Run #72: https://github.com/m5ham3ds/KELIVO/actions/runs/44969006889  
Commit: 94286ca8b07987d3a78bc81b2c01930eb4df88e4  
Date: 22 November 2026

- Android JVM/Robolectric, vendored package tests, Flutter analysis, Arabic parity, Phase 13P emulator E2E, Release build and artifact upload passed.
- Arabic: 4,680 translations of 4,801 messages (97.48%); 121 English fallbacks.
- APK: Kelivo-Android-arm64-v8a-1.3.4+84-release.apk, 41,825,267 bytes.
- SHA-256: a6271844472413909fa927b5220601dc2825b86e1b01386ef3bc2cce6a56a3a3.
- Archive inspection: 18 native .so files, all under arm64-v8a/.
- Analyzer: zero errors/warnings, 82 info-level lint suggestions remain.

See phases/README.md for the curated roadmap. The immediate next scope is Phase 13Q: secure, read-only Skill MCP config discovery followed by a user-approved lifecycle for tools/list and tools/call. Import must never start a server.
