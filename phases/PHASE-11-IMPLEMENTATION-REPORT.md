# Phase 11 — Implementation Report

**Status:** Phase 11 source implementation prepared; not formally accepted. Dart analysis, Flutter tests, Android ARM64 Release build and real phone media QA have not been run in this preparation environment because Dart/Flutter SDKs are unavailable here.

## Delivered changes

### New media QA service

- Added `lib/core/services/video_quality/video_quality_service.dart`.
- Added ffprobe metadata parsing and profile checks for MP4-compatible container metadata, video stream, dimensions, FPS, frame count where available, duration, codecs, audio policy and audio/video stream offsets/duration.
- Added SRT/WebVTT-style cue timestamp validation for malformed/reversed time ranges, cue ordering, overlaps and out-of-duration cues.
- Added optional ffmpeg black-frame/silence scans and bounded contact sheet generation (up to 12 samples).
- Added JSON report persistence, prior-baseline comparison, error classification and failed-hybrid-scene recovery.

### Recovery and data protection

- Recovery is restricted to one saved hybrid scene with `failed` state. It reuses Phase 10 `run_scene` with `retry: true` and does not resubmit completed scenes.
- Each scene gets at most two extra QA recovery attempts; the ledger is stored separately from source assets.
- Reports and contact sheets are stored under `.kelivo/quality/`; original MP4, subtitle and scene outputs are never overwritten.
- Video/subtitle paths must resolve to regular non-symlink Workspace files. Input size and command output are bounded.
- Missing binaries are reported with a project Runtime Profile/package-manager suggestion. No package is silently installed. Script exceptions are classified for investigation; no arbitrary package is added.

### Conversation and UI integration

- Registered the structured `video_quality` tool and reserved its name from MCP collisions.
- Added a dedicated workspace tool card and UI regression.
- Mutating/expensive operations (`inspect` report persistence, `deep_scan`, `samples`, `compare`, and `retry_scene`) follow the explicit tool approval flow.

### CI

- Added `.github/ci/android-phase11-test-manifest.txt`, retaining the focused Phase 3–10 regression scope and adding Phase 11 QA tests.
- Added `analyze_android_phase11.sh` and `test_android_phase11.sh`.
- Updated Android build and PR diagnostic workflows to the Phase 11 focused scope.
- Updated `audit_android_only.sh` to enforce the Phase 11 manifest and nine exact Android workspace-tool UI regressions.

## Verification performed in the preparation environment

- The worktree is derived from `KELIVO-PHASE10.zip`, whose source archive passed `unzip -t` before modification.
- Shell syntax and YAML parsing are checked during final packaging.
- Manifest completeness and exact UI test selector are checked before delivery.
- Dart/Flutter executables are not installed in this preparation environment; `dart format`, `dart analyze`, `flutter test`, Android ARM64 build and device-level FFmpeg/MP4 QA are therefore not claimed as run.

## Known limitations

- FFmpeg/ffprobe must be installed by the user in the selected PRoot distribution/Runtime Profile. This phase does not bundle them or install them automatically.
- Deep black/silence scans are diagnostic signals and can flag intentional creative content.
- The generated contact sheet requires a separate `view_image` tool call for visual inspection; no vision-model judgment is asserted.
- Subtitle checks are timestamp-focused; visual safe-area/position and semantic text checks are deferred.
- Retry automation is currently scoped to failed Phase 10 hybrid scenes only, with two additional attempts per scene. Generic engine/provider recovery, auto code editing and automatic package repair remain deferred.
- Existing Phase 3–10 acceptance gates remain pending where recorded. Phase 11 must not be marked accepted until focused CI, ARM64 Release and device media QA all pass.
