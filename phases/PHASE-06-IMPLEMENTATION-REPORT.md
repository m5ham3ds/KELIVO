# Phase 6 Implementation Report — Runtime Profiles & Execution Isolation

## Summary

Implemented the first usable Runtime Profile control plane and wired project profiles into workspace shell execution and Python/Node package-manager targets. Updated Android CI to analyze production sources and run the focused Phase 6 regression manifest.

## Implementation

- Added `RuntimeProfile`, `RuntimeResourceLimits`, `RuntimeProcessRecord`, `RuntimeProfileExecution` and validation/path helpers.
- Added a persistence-backed `RuntimeProfileService` for create/list/inspect/remove/default selection, scoped validation, concurrency reservations, process history, cancellation and interrupted-run recovery.
- Python profiles provision an independent `venv`; Node profiles use a per-profile local prefix/root.
- Workspace stores an optional default profile ID. Shell calls use it unless an explicit `runtime_profile_id` is supplied.
- Each profile run gets an isolated `TMPDIR` and persistent `KELIVO_TASK_OUTPUT_DIR`. TMP is cleaned after normal completion; stale TMP paths from interrupted runs are cleaned best-effort on the next profile run.
- Profile runtime environment controls PATH, VIRTUAL_ENV, NODE_PATH and non-secret custom variables. Reserved paths, shell-control variables and secret-like keys are rejected.
- Added `runtime_profile` conversation tool with user approval required for mutations.
- Python/Node project package operations inherit the workspace default profile; apt/apk remain shared PRoot packages.
- Added best-effort `ulimit` ceilings for process count, virtual memory and max file size, plus command timeout, concurrency ceiling and post-run TMP size checks.
- Updated Phase 6 Android-only test scripts, manifest and workflow calls.

## Tests added/updated

- `runtime_profile_models_test.dart`: limits normalization/serialization, invalid environment handling and process session serialization.
- `runtime_profile_service_test.dart`: Python/Node provisioning, independent profile roots, per-run TMP/output paths, environment/PATH behavior, resource prefix, shared concurrency reservations, process session recovery, cleanup of stale TMP and PRoot requirements for extension profiles.
- Updated workspace serialization/default-profile test.
- Updated built-in tool catalog/name test for `runtime_profile`.
- Updated package-manager test proving project Python pin operations use the default Runtime Profile root.

CI manifest: 26 focused test files plus four named chat UI regressions. No non-Android platform tests were added.

## Validation performed in the packaging environment

- YAML parsing for modified workflow/config files.
- `bash -n` on modified Phase 6 shell scripts.
- Android-only audit, including ARM64 PRoot library/checksum validation and manifest platform-scope checks.
- Manifest existence and focused-test count checks.
- ZIP integrity verification.

Dart/Flutter SDK was unavailable, so Dart analysis, Flutter tests and APK building were **not run locally**. GitHub Actions remains the acceptance gate.

## Known limitations

- Profiles are logical package/path isolation inside one PRoot, not kernel namespaces, seccomp or a strong security boundary.
- Base system packages and Python/Node interpreters remain shared. Multiple interpreter versions are not managed in this phase.
- `ulimit` constraints are best-effort; memory is virtual-memory limit, not guaranteed physical RAM.
- TMP size is checked after command completion, not enforced as a live disk quota.
- PTY/interactive Terminal is not Runtime-Profile-aware yet. The current connection covers one-shot workspace `shell` commands.
- Task profiles are modeled but not exposed in the chat tool; extension profiles can be provisioned/managed but require a future Skill runtime executor for direct Skill execution.
- Remote runtime providers are not implemented.
- Restart recovery marks old runs interrupted and supplies a resume hint; it cannot restart the original native process.
- Persistent output directories currently require user/project cleanup; no Artifact Manager retention policy exists yet.

## Acceptance

Source changes and static package checks are prepared. Phase 6 is **not formally accepted** until GitHub Actions passes analysis, the 26 focused test files, four named UI regressions, Android ARM64 Release build and artifact upload, followed by on-device validation of two projects with conflicting Python/Node requirements.
