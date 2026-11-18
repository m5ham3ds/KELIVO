# KELIVO — Phase 13C Implementation Report

**Date:** 2026-11-10  
**Baseline:** `1.3.4+84`  
**Checkpoint:** Source prepared; **not accepted**.  
**Scope:** Phase 13C only. Phase 13D was not started.

## 1. Executive summary

Phase 13C now connects project Runtime Profiles to the Android Workspace settings flow, makes media dependencies discoverable and inspectable, clarifies package scope semantics, and applies the existing resource model to project commands and video-render outputs.

This checkpoint was prepared at the user's direct request while the formal acceptance gates for Phases 13A and 13B remain open. It does **not** mark 13A or 13B accepted, and it does not close the outstanding 13B MCP adapter requirement (`tools/list` / `tools/call`). CI, Flutter tests, and an ARM64 APK build still need to run in GitHub Actions, followed by phone validation.

## 2. Implemented behavior

### 2.1 Workspace Runtime Profiles

- Added `RuntimeProfilesPage` and a navigation entry in mobile Workspace settings.
- The page selects a Workspace and lists **project-owned** profiles for that Workspace.
- Users can create, edit, remove, and set/clear a project default profile. Editing changes settings and limits without recreating existing Python/Node package roots; the service rejects edits while that profile has active runs.
- The page displays current active runs and exposes cancellation through the existing runtime process service.
- Profile configuration exposes ecosystems and limits for wall-clock duration, CPU time, concurrent runs, processes, virtual memory, temporary storage, output storage, and a single file.
- The page deliberately does not present extension/task profiles as project profiles. Skill/extension-owned profiles remain attached to their respective owner flow; task profiles are not exposed in this page.

### 2.2 Media tools and environment inspection

- Added `EnvironmentDependency.mediaTools` as an explicit optional preset.
- The preset installs only the OS package `ffmpeg` when the user initiates installation. FFprobe is checked separately and is expected to be provided by the FFmpeg package for the selected supported distribution.
- The environment probe captures the first line of `ffmpeg -version` and `ffprobe -version`, with each value capped at 160 characters.
- Optional command-presence checks cover `yt-dlp`, `mediainfo`, `ffmpegthumbnailer`, and ImageMagick command names (`magick`, `convert`, `identify`). These optional tools are detection-only; the preset does not install them. Command presence is not a guarantee that every command belongs to the same vendor/version family.
- The Environment UI shows the detected FFmpeg/FFprobe version strings and the status of optional media commands. It reports unknown when a complete probe result is unavailable.

### 2.3 Package scopes and RootFS semantics

- Updated the package-manager tool description to distinguish shared OS packages from language package roots.
- `apt`/`apk` remain runtime-scoped and modify the **single active shared RootFS**.
- Python/Node packages retain their existing runtime/project/extension/task or matching Runtime Profile scopes; a project Runtime Profile isolates package directories, not the interpreter executable itself.
- The current installer uses one active RootFS location and stages replacement when changing the selected image. This is not simultaneous Ubuntu/Alpine/Debian multi-rootfs support.
- No per-profile Python or Node interpreter-version manager was added. Runtime Profiles use the interpreter versions installed in the active RootFS.

### 2.4 Resource controls and video render integration

- Project command profiles apply a best-effort shell `RLIMIT_CPU` (`ulimit -t`) together with the existing process, virtual-memory and file-size shell limits.
- Wall-clock timeout and cancellation continue to use the runtime process API.
- Temporary and profile output directories are measured after a command completes. They are not live filesystem quotas.
- `VideoEngineService.render` now applies the selected project's `maxOutputMegabytes` budget to the primary rendered artifact after rendering. Without a selected project profile, it uses the default 1024 MB budget. If the primary output exceeds the budget, that file is deleted and the render is reported as failed. Sidecar files and the whole project directory are not included in this primary-artifact check.
- Android memory/storage/thermal telemetry is sampled before a render through the existing device resource monitor. It can warn or block before rendering, but it is not continuous thermal/resource enforcement during a long render. Android still controls system throttling.
- No claim is made that PRoot limits are kernel-enforced resource quotas or a security boundary.

## 3. Tests and CI

A focused runner was added at `.github/scripts/run_phase13c_workspace_environment_tests.sh` and registered in `.github/workflows/android-build.yml` after the Phase 13B focused test step. It runs only:

- `test/core/services/sandbox/environment_dependencies_test.dart`
- `test/core/services/packages/package_manager_service_test.dart`
- `test/core/services/video_engines/video_engine_service_safety_test.dart`

The existing Phase 13B focused runner continues to cover `runtime_profile_models_test.dart` and `runtime_profile_service_test.dart`, including normalized CPU/output limits, serialization, command wrapping, profile updates, and active-run mutation rejection.

Additional assertions cover the media preset's FFmpeg package, paired FFmpeg/FFprobe probes, version capture, optional-tool detection-only behavior, and output-size acceptance/rejection at the configured boundary.

**These Flutter tests were added/registered but were not executed in the local preparation environment.** See the diagnostics report for the exact toolchain limitation. No APK build result is claimed.

## 4. Main source files changed

- `lib/features/workspace/pages/runtime_profiles_page.dart` — new project Runtime Profiles page.
- `lib/features/workspace/pages/workspace_settings_page.dart` — mobile Workspace settings navigation.
- `lib/core/services/runtime_profiles/runtime_profile_models.dart` — CPU/output limits and post-run output directory checks.
- `lib/core/services/runtime_profiles/runtime_profile_service.dart` — project-profile settings updates and CPU limit in project/Skill command prefixes.
- `lib/core/services/runtime_profiles/runtime_profile_tools.dart` — exposed limit fields and accurate best-effort/post-run descriptions.
- `lib/core/services/sandbox/environment_dependencies.dart` — media preset, version probes and optional media command checks.
- `lib/features/workspace/widgets/environment/environment_dependencies_section.dart` — media version and optional-tool status UI.
- `lib/core/services/packages/package_manager_tools.dart` — package-scope descriptions.
- `lib/core/services/video_engines/video_engine_service.dart` — post-render primary-artifact output budget.
- `lib/l10n/app_{en,ar,zh,zh_Hans,zh_Hant}.arb` and generated localization files — Runtime Profile and media UI strings.
- Tests under `test/core/services/runtime_profiles/`, `test/core/services/sandbox/`, and `test/core/services/video_engines/`.
- `.github/scripts/run_phase13c_workspace_environment_tests.sh` and `.github/workflows/android-build.yml` — focused CI test registration.
- `phases/README.md`, `phases/MASTER-DEVELOPMENT-PLAN-AR.md`, and this Phase 13 plan/report.

## 5. Explicitly not implemented in 13C

- No simultaneous multi-RootFS manager.
- No Python/Node interpreter version manager.
- No automatic installation of optional media tools such as yt-dlp, MediaInfo or ImageMagick.
- No continuous thermal enforcement, live filesystem quota, or guaranteed physical RAM quota.
- No extension/task profile management UI in the project Workspace screen.
- No MCP adapter, execution staging hardening, credential inheritance redesign, or Phase 13D security work.

## 6. Remaining validation / acceptance gates

1. Run the Android GitHub Actions workflow and inspect all Phase 13A/13B/13C focused test results, localization generation, and ARM64 Release APK packaging.
2. On the Android phone, open Workspace settings and verify project profile create/edit/default/remove and process cancellation.
3. Install the Media Tools preset only by explicit user action; verify `ffmpeg -version` and `ffprobe -version` display their detected strings.
4. Verify optional media tools show installed/missing/unknown accurately and are not installed by the preset.
5. Verify apt/apk changes the active shared RootFS and Python/Node packages remain in their intended package roots.
6. Run a short render with a known-small output; verify normal playback and that an intentionally low output budget rejects and removes an oversized primary artifact.
7. Run a harmless long command/render and test timeout and cancellation. Check that thermal/storage readings are treated as preflight only.
8. Verify changing Ubuntu/Alpine/Debian replaces the one active RootFS rather than implying multiple mounted rootfs instances.
9. Reconcile Phase 13A/13B acceptance separately; Phase 13B still needs an explicit MCP lifecycle adapter before it can be called complete.

**Final status:** Phase 13C source checkpoint prepared; CI and device acceptance pending. Phase 13D has not started.
