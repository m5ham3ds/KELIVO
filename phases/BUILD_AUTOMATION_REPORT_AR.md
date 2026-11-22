# KELIVO — Automation build report

## Events
push to main, pull request create/update, and manual workflow dispatch.

## Active pipeline
1. Checkout and initialize report.
2. Android-only and release-hardening audits.
3. Flutter 3.47.6 dependency resolution and Linux GTK/GLib native-asset prerequisites.
4. Arabic ARB key/placeholder parity and gen-l10n.
5. Flutter static analysis across lib, test and integration_test.
6. Focused Phase 13Q read-only Skill MCP configuration tests.
7. Independent tests for mcp_client, downsize, flutter_math_fork, markstream, terminal_view.
8. Java 21, Gradle 8.14, NDK 28.2.13676358 and CMake 3.22.1.
9. Android JVM/Robolectric suite.
10. Four Android emulator integration files on main, including Phase 13P Skill lifecycle.
11. Build-mode plugin registrant preparation.
12. ARM64 APK build, actual APK archive ABI validation, SHA-256 and upload.
13. Separate report job captures logs and publishes a Markdown build report where possible.

## Not run by this workflow
- The complete root Flutter unit/widget test suite.
- Historical focused regression suites for Phases 13E–13O.
- MCP server startup or Skill-owned tools/list/tools/call. The Phase 13Q parser test is read-only.

Broad warning/error Regex totals are text matches, not counts of failing gates. Expected negative-test messages and words such as error in test names can be included; use GitHub Actions step conclusions to decide pass/fail.

## Last verified run
CI #72: https://github.com/m5ham3ds/KELIVO/actions/runs/44969006889  
Commit 94286ca8b07987d3a78bc81b2c01930eb4df88e4  
APK 41,825,267 bytes; 18 .so files within arm64-v8a only; SHA-256 a6271844472413909fa927b5220601dc2825b86e1b01386ef3bc2cce6a56a3a3.  
Arabic parity: 4,801 messages; 4,680 Arabic translations (97.48%); 121 English fallbacks.
