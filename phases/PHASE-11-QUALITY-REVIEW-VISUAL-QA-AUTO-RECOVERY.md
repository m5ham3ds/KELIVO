# Phase 11 — Quality Review, Visual QA & Auto Recovery

**Status:** Source implementation prepared; formal acceptance is pending. This phase adds a Workspace-scoped `video_quality` tool. It does not claim that a video is production-verified until Android CI, ARM64 build and real device media QA pass.

## Scope delivered

### Media metadata and profile validation

- Run `ffprobe` only inside the selected Android PRoot runtime and optional project Runtime Profile. Neither `ffmpeg` nor `ffprobe` is bundled into the APK.
- Inspect the actual container and streams, including duration, container name, codec, dimensions, frame rate, frame count when exposed, audio presence, stream start times and audio/video duration difference.
- Compare observed metadata against optional expected width, height, FPS, duration and audio policy. MP4-compatible containers are checked from ffprobe metadata, not from the filename extension.
- Bound media input to a Workspace file no larger than 5 GiB and reject paths outside the Workspace, symbolic links, missing files and empty files.

### Audio/video and subtitle QA

- Compare first audio/video stream start offsets and available stream durations with warning thresholds.
- Parse SRT and WebVTT-style timestamp cues, validate start/end order, detect overlapping or out-of-order cues, and warn when cues exceed the video duration.
- Optional `deep_scan` runs FFmpeg `blackdetect` and `silencedetect`. These are review signals, not automatic defects: intentional fades, black title cards and quiet scenes can be valid.
- Optional `samples` creates a bounded contact sheet (1–12 requested samples) under `.kelivo/quality/`. Use the existing `view_image` tool to inspect the contact sheet visually.

### Reports and comparisons

- Save the latest JSON report under the selected project’s `.kelivo/quality/latest-report.json` using a temporary file and rename.
- `compare` compares the new run with a separately retained `previous-report.json` baseline. The comparison updates the baseline only after a valid current report is available.
- QA never overwrites or deletes source videos, scene clips, subtitles or engine outputs. Reports, recovery state and contact sheets are separate derived artifacts.

### Diagnosis and bounded recovery

- Classify common failures: missing binaries/files, invalid or incomplete media, timeout, out-of-memory/resource exhaustion, network interruptions, and script/syntax failures.
- Return targeted next steps. For a missing `ffmpeg`/`ffprobe`, recommend the `ffmpeg` package through `package_manager` in the selected project Runtime Profile; installation is not automatic and requires an explicit user-approved package operation.
- `retry_scene` is available only for a scene whose saved hybrid-workflow state is `failed`. It calls Phase 10's single-scene retry path, never re-renders completed scenes, and limits QA recovery to two additional attempts per scene. The attempt ledger is stored at `.kelivo/quality/recovery-state.json`.
- No automatic dependency changes are made for a script exception. A stack trace must be inspected before proposing a package change.

## Conversation tool

`video_quality` actions:

- `inspect`: ffprobe validation, expected profile checks, optional subtitle validation and report persistence.
- `deep_scan`: optional black-frame and silence scan; requires approval because it may consume CPU/time.
- `samples`: generates a contact sheet; requires approval because it writes files.
- `compare`: compares the current media report with the previous QA baseline.
- `diagnose`: classifies an error or inspects a specific video.
- `retry_scene`: retries one failed hybrid scene within the bounded recovery policy and requires approval.

The tool does not accept credentials or arbitrary commands. Media and subtitle paths must resolve to regular files inside the Workspace. Commands are constructed from fixed FFmpeg/ffprobe arguments and quoted paths, with process timeout, bounded output collection and Runtime Profile accounting.

## Focused tests and CI

- `video_quality_service_test.dart` covers ffprobe metadata parsing, profile mismatches, audio policy, subtitle timing/overlap checks and common failure classification.
- `workspace_tool_ui_test.dart` includes the quality review tool card regression.
- Android CI uses `.github/ci/android-phase11-test-manifest.txt`, `analyze_android_phase11.sh` and `test_android_phase11.sh`. Prior focused Phase 3–10 regressions remain in the manifest.
- The Android-only audit checks the phase 11 manifest, runner scripts and exact nine named chat UI regressions.

## Acceptance criteria

1. Dart analysis and the Phase 11 focused test suite pass in GitHub Actions.
2. Android ARM64 Release build passes.
3. On an ARM64 Android phone with a user-selected PRoot profile, ffprobe correctly inspects a valid MP4 and rejects corrupt/truncated media.
4. Tests with known sample media detect dimensions/FPS/duration mismatches, no-video streams, wrong audio policy and measurable audio/video start or duration offsets.
5. Black-frame/silence scans and contact-sheet generation run with a compatible ffmpeg installation and create reports/artifacts only inside the Workspace.
6. Valid and invalid SRT/VTT cues are reported accurately against actual video duration.
7. A failed hybrid scene can be retried without rerunning completed scenes; a third recovery attempt is blocked.
8. Missing ffmpeg/ffprobe produces a scoped package-manager suggestion but does not silently install software.

## Explicit limitations

- No actual MP4 has been processed in this preparation environment. No statement is made that a codec, provider, engine or media file has passed end-to-end QA.
- `ffprobe` metadata cannot prove semantic correctness. Black/silence filters flag intervals for human review and may report intentional content.
- The contact sheet is produced for a separate `view_image` inspection; this phase does not run an independent vision model or assert that all frames are visually correct.
- Subtitle validation checks timing/order/overlap and duration only. It does not perform OCR, semantic translation review, safe-area detection or pixel-level subtitle placement.
- Automatic package installation, automatic code modification, production-workflow resume after process death, and retries of generic non-hybrid engine jobs are not implemented. Package installs and mutating retry actions require explicit approval.
- PRoot and Runtime Profiles provide logical process/path scoping, not a kernel security boundary.
- Earlier Phase 3–10 acceptance gates remain pending where recorded. Phase 2 remains the only phase with supplied successful CI and ARM64 build acceptance evidence.
