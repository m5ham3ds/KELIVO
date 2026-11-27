# KELIVO — Automation build report

## Events
push to main, pull request create/update, and manual workflow dispatch.

## Active pipeline
1. Checkout and initialize report.
2. Android-only and release-hardening audits.
3. Flutter 3.47.6 dependency resolution and Linux GTK/GLib native-asset prerequisites.
4. Arabic ARB key/placeholder parity and gen-l10n.
5. Flutter static analysis across lib, test and integration_test.
6. Phase 14E.2 turn-scoped Tool Registry gateway tests, plus Registry, built-in catalog, MCP service, ToolHandler, message-generation protocol and tool-loop regressions.
7. Phase 13Q Skill-owned MCP lifecycle and Phase 14D real Linux STDIO child-process integration tests.
8. Independent tests for mcp_client, downsize, flutter_math_fork, markstream, terminal_view.
9. Java 21, Gradle 8.14, NDK 28.2.13676358 and CMake 3.22.1.
10. Android JVM/Robolectric suite.
11. Four Android emulator integration files on main, including Phase 13P Skill lifecycle.
12. Build-mode plugin registrant preparation.
13. ARM64 APK build, actual APK archive ABI validation, SHA-256 and upload.
14. Separate report job captures logs and publishes a Markdown build report where possible.

## Not run by this workflow
- The complete root Flutter unit/widget test suite.
- Historical focused regression suites for Phases 13E–13O.
- The complete root Flutter unit/widget test suite and historical focused regression suites for Phases 13E–13O.

Broad warning/error Regex totals are text matches, not counts of failing gates. Expected negative-test messages and words such as error in test names can be included; use GitHub Actions step conclusions to decide pass/fail.

## Last verified run — CI #208
[CI #208](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283) on `main` commit `77736b783d55752a35a3aeb3b66b6b6dce7e87f1` succeeded. Both the Android ARM64 build job and Markdown report job completed successfully. Flutter Analyze, Environment lifecycle, Phase 14A/14B, Phase 14E.2 Tool Registry gateway, Gemini/OAuth, Phase 14C.4, Phase 13Q/14D real STDIO, five local package suites, Android JVM/Robolectric, Phase 13P Android Emulator, ARM64 APK build/ABI verification/SHA-256 upload and report publication passed.

APK: 41,943,583 bytes; `arm64-v8a` only; SHA-256 `29fa1b9db0223dd0b9c6d8f170af3b86f6d44f2f5dd88a992843bd09f907f6fa`; APK Artifact ID `15167472926`; Build report Artifact ID `15167378117`; Raw diagnostics Artifact ID `15167717401`.

**Phase 14E status:** 14E.1 targeted tests passed in CI #206. 14E.2 turn-scoped conversation integration tests passed in CI #208. Phase 14E as a whole remains open pending native Toolset composition, complete built-in tool parity and real direct/deferred/hidden exposure acceptance.
