# KELIVO — Automation build report

## Events
push to main, pull request create/update, and manual workflow dispatch.

## Active pipeline
1. Checkout and initialize report.
2. Android-only and release-hardening audits.
3. Flutter 3.47.6 dependency resolution and Linux GTK/GLib native-asset prerequisites.
4. Arabic ARB key/placeholder parity and gen-l10n.
5. Flutter static analysis across lib, test and integration_test.
6. Phase 14E.1 namespaced Tool Registry/Toolsets/deferred exposure tests, plus built-in catalog and MCP route regression tests.
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

## Last verified run — CI #204
[CI #204](https://github.com/m5ham3ds/KELIVO/actions/runs/45899864988) on `main` commit `e1e543d77f38c6de15ad16aea972afa6bd06e8aa` succeeded. Phase 14D real STDIO integration passed (48 tests); Android JVM/Robolectric, Phase 13P emulator and ARM64 release build passed. APK 41,930,839 bytes; arm64-v8a only; SHA-256 `4f38e0c520386f43427eee822811dd02c42393de4f4037a7ae32a6bc995ae8dd`; Artifact ID `15156492027`.

**Phase 14E.1:** Tool Registry foundation is now included in the workflow and awaits CI #205.
