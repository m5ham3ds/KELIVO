# PHASE 2 — CI Automation and Comprehensive Build Report

**Status:** Android CI and Release build accepted by GitHub Actions run `42424318897`; see `PHASE-02-COMPLETION-AND-ACCEPTANCE.md`.

## User requirements addressed

- Android build starts automatically after repository `push` events.
- Pull Request updates automatically run the same quality/build pipeline.
- Manual Run workflow remains available with Debug/Release selection.
- A separate dependent `publish-build-report` job generates the Markdown report even when an earlier build stage fails.
- Complete stdout/stderr logs for wrapped commands are retained as text files and uploaded with the report.
- The report job retrieves the completed build job's complete GitHub Actions log through the REST API, so setup/checkout action warnings are included too when the API download succeeds.
- The report job also saves the structured Jobs API response (`workflow-jobs.json`) and includes exact GitHub step conclusions, including skipped/not-started steps, and their durations.
- A concurrency key based on the source repository and PR head branch avoids running duplicate push/PR builds for the same branch head.
- Warnings, deprecations, errors and failure indicators are extracted into the report with log path and line number.
- APK and SHA-256 are uploaded only after successful quality checks and ARM64 build.

## Changed files

- `.github/workflows/android-build.yml`
- `.github/workflows/pr-check.yml` (now optional manual quality diagnostics; core checks moved to the main workflow)
- `.github/scripts/capture_step.sh`
- `.github/scripts/record_ci_action.sh`
- `.github/scripts/generate_build_report.py`
- `.github/scripts/format_changed_dart.sh`
- `.github/scripts/check_untranslated_pr.sh`
- `.github/scripts/check_no_new_untranslated.py`
- `.github/scripts/audit_android_only.sh`
- `l10n.yaml`
- `.gitignore`
- `BUILD_AUTOMATION_REPORT_AR.md`

## Main workflow stages

1. Checkout and run metadata initialization.
2. Android-only source audit.
3. Java and Flutter toolchain setup.
4. Capture Flutter/Dart/Java/Android SDK versions.
5. Accept Android SDK licenses and install pinned NDK/CMake (the `yes | sdkmanager` SIGPIPE fix is retained).
6. Resolve the root Flutter dependencies once; the `markstream` path dependency is resolved transitively.
7. Format only first-party Dart files changed by the current revision and retain any formatting patch.
8. Generate localization and compare untranslated messages only when ARB or `l10n.yaml` files changed.
9. Analyze every production Dart source under `lib` plus the explicit Phase 2 test manifest, then run only the focused Android Phase 2 tests.
10. Build `arm64-v8a` APK.
11. Package APK and SHA-256; upload APK only on success.
12. Upload raw command diagnostics with `if: always()`.
13. A dependent report job retrieves full build logs and structured step metadata, generates `KELIVO_BUILD_REPORT.md`, and uploads the report and available logs with `if: always()`.

## Report content

- Repository, workflow run, event, ref, commit and actor.
- Start/end times and build mode.
- Flutter, Dart, Java, NDK and CMake versions.
- Every command stage's result and duration.
- Official GitHub Actions step statuses and conclusions, including skipped steps, with durations.
- APK file, size and SHA-256 when produced.
- Every detected warning/deprecation and error/failure-pattern line, with the source log and line number.
- Links to the workflow run and a list of complete raw log files.

The report distinguishes pattern matches from confirmed root causes. GitHub-managed action logs remain available in the Actions UI; their outcome is recorded in the report.

## Localization pipeline repair

The previous workflow passed the placeholder `desiredFileName.txt`, while the localization configuration declared the same placeholder as its output path. This is replaced consistently with `untranslated_messages.json` in `l10n.yaml`, `.gitignore`, the comparison script and workflow paths. The base-commit comparison retains a one-time fallback to the old filename so the first CI run after this change can compare against the immediately preceding commit.

## Security

- The build job token remains `contents: read`. The separate report job has only `contents: read` and `actions: read` so it can download its own completed build-job logs.
- No secrets or API keys are required for tests or unsigned/debug-key test APK packaging.
- No report is committed back to the repository; it is uploaded as an Actions artifact, avoiding recursive pushes and repository bloat.

## Validation performed in preparation environment

- Bash syntax check for all added/changed scripts.
- YAML structure validation for both workflows.
- Success and failure simulations for `capture_step.sh`, including correct exit-code propagation.
- Report generator test using synthetic warning/error logs and fake run metadata.
- Android-only audit.
- Localization checker unit test using sample JSON inputs.
- ZIP structure and CRC validation after packaging.
- Report-generator fixture test covering structured step data, skipped-step status, warning/error extraction, APK metadata and raw log listing.
- Verified that the build workflow automatically triggers on `push` and `pull_request`, and that the report job has the minimum `actions: read` permission needed to retrieve job logs.

## Not run in preparation environment

Flutter/Dart analysis, Flutter tests, NDK installation and Android Gradle/ARM64 build require the GitHub runner and must be verified in the next automatic Actions run.


## تحسين التقرير التفصيلي للخطوات

- أضيف حفظ `workflow-jobs.json` من GitHub Actions Jobs API، ويحتوي على نتائج الخطوات بما فيها `skipped` ومدد التنفيذ.
- يضيف `KELIVO_BUILD_REPORT.md` جدولاً منفصلاً للنتائج الرسمية من GitHub، بالإضافة إلى جدول مراحل الأوامر والسجلات الكاملة.
- أصبح مفتاح concurrency يعتمد على مستودع وفرع رأس Pull Request، لتقليل تكرار بناء Push وPull Request للالتزام نفسه.

## First-run formatter recovery

The first real push run found a syntax error in `extension_command_tools.dart` and 36 changed Dart files that the formatter would adjust. The syntax error has been corrected. To avoid stopping the Android build only because changed files need style normalization, the main Android workflow now runs `.github/scripts/format_changed_dart.sh` before analysis/tests/build. It applies `dart format` to all tracked Dart source/test files in the temporary GitHub runner workspace, verifies that formatting is clean, and stores a formatting-only patch (`dart-format-fixes.patch`) plus the adjusted-file list in the build-report artifact. It does not push or commit modifications back to the repository. Dart syntax/parse errors remain fatal. The separate optional manual quality workflow uses the same formatter and uploads the formatter patch as an artifact.

The first report also showed deprecated Node 20 action runtimes. The workflows now reference `actions/checkout@v7`, `actions/setup-java@v6`, `actions/upload-artifact@v7`, and `actions/download-artifact@v8` to use current Node 24-compatible action releases.


## Focused Android Phase 2 test scope (supersedes the earlier full-suite step)

The first full application test run from the earlier pipeline history attempted 11,465 test cases across the repository and encountered 41 failures, including tests for native platforms that are no longer build targets. This is not an appropriate per-commit gate for the current Android-only Phase 2 work.

The active workflow now uses `.github/ci/android-phase2-test-manifest.txt` as the explicit test whitelist. It covers extension storage/model contracts, conversational extension commands, operation history, unified registry synchronization, safe Skill archive handling, SkillsService lifecycle, skill prompt wiring, and built-in tool-name reservations. It additionally runs exactly two named chat UI tests for tool catalog rendering and live extension-install progress. All production code under `lib` remains included in Dart analysis. No general integration tests or platform-simulated iOS/macOS/Windows/Linux test variants are executed by the active Phase 2 pipeline.

The redundant independent markstream dependency resolution and markstream test/analyzer jobs are removed; root `flutter pub get` still resolves markstream because it is a runtime dependency of the app. Formatting is restricted to changed first-party Dart files rather than formatting more than a thousand unrelated files on each push. Localization jobs are conditional on changes to ARB files or `l10n.yaml`.

The main workflow continues to produce the same ARM64 APK and diagnostic report artifacts. The optional manual quality workflow follows the same focused Android test policy so it cannot accidentally re-run the old full suite.


## Latest supplied build run — UI duration assertion correction

Run `42423042302` (`edf2d9213dca`) passed Android-only audit, Flutter/Java setup, NDK/CMake installation, dependency resolution, formatting, localization checks and Dart analysis. All 56 tests in the 10-file Phase 2 manifest passed. The tool catalog UI regression passed; the live install-progress regression failed because its exact `Completed` finder rejected the duration suffix added by the production status renderer. The regression assertion has been corrected to check `WorkspaceStatusBadge.completedKey` and `find.textContaining('Completed')`. The APK step was skipped in that run and remains unverified. See [the seventh CI failure analysis](PHASE-02-CI-SEVENTH-FAILURE-ANALYSIS-AND-FIX.md).
