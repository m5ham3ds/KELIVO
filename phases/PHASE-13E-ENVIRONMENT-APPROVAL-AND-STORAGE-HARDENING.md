# KELIVO Phase 13E — Environment Inventory, Manual Mutation Approval & Durable Public Storage

**Checkpoint date:** 2026-11-11  
**Project baseline:** `1.3.4+84`  
**Status:** Source checkpoint prepared; **not accepted**. Flutter/Dart analysis, Flutter tests, Android ARM64 Release build, and phone acceptance remain pending.

## 1. Why this follow-up exists

The Phase 13 review identified three product gaps that are separate from the earlier Skill import/execution work:

1. Assistant diagnostics must distinguish the Android PRoot host runtime, the installed guest RootFS, a real guest session, and the packages/tools installed inside the guest. Checking `command -v proot` or asking APT for a package named `proot` inside Ubuntu is not a valid host-runtime check.
2. A read-only update check must be separate from `extension_update`, and every assistant-triggered state-changing Skill/package action must require fresh manual approval even in Full Access mode.
3. User-owned outputs need a durable, visible Android folder. App-private directories remain the runtime source of truth; public storage is an export/import boundary and must not be treated as a guest filesystem path.

This checkpoint extends the existing Phase 13A–13D approach. It does not replace the import manifest, Skill executor, Runtime Profile, or shared-RootFS security boundaries already documented in those reports.

## 2. Assistant environment diagnostics

### `environment_status`

A new read-only built-in assistant tool is registered in the tool catalog and dispatcher. It reports the following independently:

- Environment provider state: install phase, distribution, version/codename, architecture, configured RootFS path, RootFS directory existence and install timestamp.
- Android PRoot runtime: the registered runtime's `status()` result. For the Android backend this follows `AndroidProotRuntime.status()`, including the native channel probe, RootFS/ABI compatibility validation and on-disk install adoption. It does not run APT or search for a `proot` executable inside Ubuntu.
- PRoot guest session: launches a fixed, harmless marker command through the real runtime, then performs inventory only if the host runtime reports ready. A successful RootFS metadata check alone is not reported as proof that a session can start.
- Guest package/tool inventory: distribution and machine data; detected package managers; installed package lists/counts from supported system, Python, Node and other package ecosystems; and common CLI-tool paths and version strings.
- KELIVO-managed package ledger: separately reports recorded package names, versions, manager/scope/status counts, and bounded full entries for the isolated runtime/project/extension/task scopes. This ledger is labelled as tracked metadata, not live filesystem verification, and complements the guest's live package inventory.

Supported inventory paths include dpkg/APT, APK, RPM/DNF/YUM, Zypper, Gentoo/Portage, XBPS, Pacman, Snap, Flatpak, Nix, Guix and Homebrew; Python/pip/pipx/pipenv/uv/Rye/Hatch/Poetry/PDM/Conda/Mamba; Node/npm/npx/pnpm/Yarn/Bun/Deno/Volta/Corepack; Cargo/Rustup, RubyGems, Composer, .NET global tools, R, LuaRocks and Elixir/Mix where installed. It also probes common CLI/runtime tools such as Git, SSH, curl/wget, archive tools, FFmpeg/FFprobe, yt-dlp, MediaInfo, ImageMagick, SQLite, jq/yq, compilers, build tools and container CLIs. Some ecosystem managers expose toolchain versions rather than a meaningful global package list; those are identified separately.

`detail=summary` returns manager/tool detection and package counts. `detail=full` includes package rows, capped at `max_items` (1–500) per ecosystem. Captured output also has a hard 2 MiB limit and reports whether it was truncated. The inventory command is fixed/read-only; it does not install, upgrade, remove, or run third-party package scripts.

**Scope limitation:** Android/Termux host packages and a separate Termux Python installation are not visible from the in-app guest runtime. The response explicitly reports this separation instead of implying that guest inventory includes host packages. The PRoot native host readiness and guest Python runtime are reported separately.

## 3. Skill update availability and mandatory approvals

### Read-only update check

- Added `extension_check_updates` with either `id` or `all=true`.
- GitHub sources compare the recorded installed commit with the latest commit resolved for the tracked ref. Commit-pinned sources are reported as pinned rather than being treated as tracking branches.
- `skills.sh` sources compare the registered catalog revision with a read-only catalog resolution.
- Local/untracked/legacy sources are reported as unsupported or unknown; the service does not guess that they are current.
- The check does not extract files into the installed Skills tree, replace Skill content, update registry metadata, create rollback snapshots, or install anything. It reports `readOnly=true` and `filesChanged=false`.
- A detected update is only a report. `extension_update` is a separate call and requests a new approval.

### Approval policy made explicit

`ExtensionCommandToolNames.requiresManualApproval` is the shared set used by the assistant dispatcher:

- `extension_install`
- `extension_update`
- `extension_enable`
- `extension_disable`
- `extension_remove`
- `extension_rollback`

Each invocation calls `authorize(needed: true, requireManualApproval: true, ...)`. Full Access and previous one-time approvals do not bypass this requirement. Read-only `extension_search`, `extension_inspect`, `extension_list` and `extension_check_updates` do not prompt for mutation approval.

Package mutation actions are similarly centralized in `PackageManagerToolNames.requiresManualApprovalActions`:

- `install`, `upgrade`, `remove`, `pin`, `unpin`

The dispatcher applies `requireManualApproval: true` to those actions regardless of Full Access. `plan`, `check`, and `list` remain read-only. Existing defaults that disable Python source builds and Node lifecycle scripts remain unchanged.

This gate covers assistant tool calls. Explicit user actions performed directly in the app's own UI continue to use their existing confirmation/interaction flows.

## 4. Durable Android storage via SAF

### Storage model

KELIVO continues to keep executable/runtime state in private app storage:

- RootFS/environment and native/runtime metadata
- Installed Skills and their import manifests/rollback data
- Runtime package scopes and databases
- Workspaces, sessions and temporary Skill execution I/O

A separate Android Storage Access Framework (SAF) tree grant is used for user-owned files. The user can choose an existing `KELIVO` folder or a parent location (for example, `Documents`). When a parent is selected, the native layer creates a `KELIVO` child folder. Under that folder it creates:

- `Projects/`
- `Results/`
- `Downloads/`
- `Skills-Exports/`
- `Reports/`
- `Backups/`

The persisted tree URI is retained by Android and its display name is stored in app preferences. A revoked/missing grant is detected and prompts the user to select a folder again.

### SAF safety constraints

- The content URI is never converted into a guest path or mounted into PRoot.
- Files are first handled in private app storage/workspaces. Exports use Android `DocumentsContract` and content streams.
- Export requests validate that source files are under KELIVO's private `dataDir`; relative destination paths reject absolute paths, `.`/`..`, control characters, excessive depth and oversized segments.
- Writes stage to a temporary document and preserve/restore an existing destination where the provider permits it.
- The new SAF feature does not request or depend on `MANAGE_EXTERNAL_STORAGE`. **The Phase 13 baseline already declares that permission and contains a separate legacy `WorkspaceDirectoryAccess` flow for arbitrary external workspace mounts; this checkpoint leaves that pre-existing feature/permission unchanged.** The SAF export path does not use it, and no new broad-storage permission was added.

### Integrated export flows

- Verified successful Skill execution artifacts are copied to `KELIVO/Results/<workspace>/<run>/<artifact>` when a public folder is configured. Export failure does not convert an otherwise successful Skill run into a failed run; warnings are attached to the result.
- Explicit Skill ZIP exports are additionally copied to `KELIVO/Skills-Exports/` while retaining the existing save/share picker flow.
- Backup exports are additionally copied to `KELIVO/Backups/` while retaining the existing native file-save flow.
- If no public folder has been selected, the original private Workspace/backup/save behavior remains in place.

`Projects/`, `Downloads/` and `Reports/` are provisioned for future import/download/report workflows; this checkpoint does not claim that every existing download or project import path is already synchronized with those folders.

## 5. Principal source changes

- `lib/core/services/sandbox/environment_status_tool.dart` — tool schema and comprehensive read-only inventory/session probe.
- `lib/features/home/services/built_in_tool_names.dart`, `lib/core/services/tools/built_in_tool_catalog.dart`, `lib/features/home/services/tool_handler_service.dart` — registration and dispatch; mandatory approval enforcement.
- `lib/core/services/extensions/extension_command_tools.dart` — `extension_check_updates` and centralized mutation approval set.
- `lib/core/services/extensions/conversational_extension_service.dart` — update-check response and read-only semantics.
- `lib/core/services/skills/skills_service.dart` — remote revision checks for GitHub and skills.sh sources.
- `lib/core/services/packages/package_manager_tools.dart` — centralized package mutation approval set.
- `lib/core/services/packages/package_manager_service.dart` — bounded read-only inventory snapshot of KELIVO-managed isolated-scope package records.
- `lib/core/services/storage/kelivo_public_storage.dart` — Flutter SAF wrapper and persisted selection.
- `android/app/src/main/kotlin/com/psyche/kelivo/MainActivity.kt` — native SAF tree selection, persisted permissions, folder structure, path validation and safe export streams.
- `lib/features/workspace/widgets/environment/environment_public_storage_section.dart` and `environment_pane.dart` — user-facing folder settings.
- `lib/features/workspace/widgets/skills/skill_detail.dart` — Skill ZIP auto-copy.
- `lib/features/backup/pages/backup_page.dart` — backup auto-copy.
- `lib/l10n/app_*.arb` and generated localization files — Arabic, English, Simplified/Traditional Chinese strings.
- Focused tests: `test/core/services/sandbox/environment_status_tool_test.dart`, the dedicated package-ledger inventory case in `test/core/services/packages/package_manager_service_test.dart`, the new read-only update-check case in `test/core/services/extensions/conversational_extension_service_test.dart`, and the isolated Phase 13E registration/approval-catalog case in `test/features/home/services/built_in_tool_names_test.dart`.
- `.github/scripts/run_phase13e_tests.sh` is the only Phase 13 test runner in the active Android build. It targets the two environment-inventory tests, the isolated package-ledger snapshot, the read-only Skill update check, and the dedicated Phase 13E registration/approval-catalog test. Tool-dispatch preflight separately verifies that both Skill and package mutation branches force `requireManualApproval: true`; no historical Full Access permission test file is rerun. Historical 13A–13D runner scripts remain for reference/manual diagnostics but are not invoked by the active build workflow.

No package/dependency, Flutter SDK, Dart SDK, Gradle, AGP, Kotlin, NDK or app-version changes are intended. `pubspec.yaml` and `pubspec.lock` are not part of this checkpoint's changes.

## 6.1 CI correction after the first Phase 13E run

The first Phase 13E CI attempt stopped in the legacy Phase 13C runner while loading `environment_status_tool_test.dart`. The diagnostic was a Dart source error in `environment_status_tool.dart`: `_buildInventoryCommand` was declared outside `EnvironmentStatusService` while referencing its private static `_inventoryScript`, followed by an unmatched closing brace. This was a Phase 13E source-compilation defect, not a failure in the Phase 13C Runtime Profile or PRoot behavior. The helper is now a static member inside `EnvironmentStatusService`, and the stray top-level declaration/brace were removed. The active workflow no longer runs the historical 13A–13D smoke runners; it runs the dedicated Phase 13E regression suite instead.

## 6. Local validation and limitations

The environment inventory's embedded shell script was extracted from the Dart raw string and checked with `bash -n` in both summary and full modes. It was also executed in the available Debian development shell: APT/dpkg returned a package count, Python/pip and Node/npm inventory ran, and common CLI version probes returned results. This only validates shell syntax and behavior against the development container; it is **not** a test of the Android PRoot runtime.

The Phase 13E runner, Phase 13E preflight, CI self-test and updated Android-only audit are checked with `bash -n`. ARB JSON parsing, localization key parity and generated-key coverage are included in final diagnostics. Flutter/Dart/Gradle availability is checked separately. If unavailable, Dart formatting/analyzer, Flutter tests and APK compilation must remain explicitly unverified. Kotlin compilation and SAF behavior also require the real Android build and device test.

## 7. Acceptance checklist

1. Run only the focused Phase 13E regression runner. The user has confirmed that Phases 13A–13D previously passed their tests and Android build; those historical suites are deliberately excluded from the current pipeline and must not be rerun as Phase 13E gates.
2. Build and install the pinned Android ARM64 Release APK; preserve the `1.3.4+84` baseline.
3. On-device, run `environment_status` with `detail=summary`; verify installed Ubuntu 24.04, correct architecture, Android PRoot runtime readiness, a successful guest session marker, and package/tool detection. Compare APT/dpkg package totals with `dpkg -l`, Python with `python3 -m pip list`, and Node with `npm list -g` inside the guest.
4. Run `environment_status` with `detail=full` and verify per-ecosystem truncation and the 2 MiB output guard. Verify the assistant never suggests installing an APT package named `proot` when the Android host runtime is already operational.
5. In Full Access mode, request each Skill mutation (install, update, enable, disable, remove and rollback) and verify every invocation presents a fresh approval. Denial must leave files/metadata unchanged.
6. In Full Access mode, request package `install`, `upgrade`, `remove`, `pin` and `unpin`; each must request a fresh approval. `plan`, `check`, `list` and `extension_check_updates` must remain read-only.
7. Install a test GitHub Skill, change its mocked/test branch commit upstream, run `extension_check_updates`, and verify it reports an update without changing `SKILL.md`, metadata or rollback history. Then request `extension_update` as a separate approved action.
8. Select a parent folder (such as Documents) and separately test selecting an existing KELIVO folder. Verify the resulting tree contains all six standard directories and that the grant survives app restart.
9. Export a harmless Skill artifact, a Skill ZIP, and a backup. Verify each copy appears in the proper directory while existing save flows remain usable. Revoke the grant and confirm KELIVO requests reselection without deleting private files.
10. Review the directory after app update/restart and ensure the public export copy remains. Uninstall behavior is expected to remove private runtime data; the user-owned public copies must remain in the selected storage provider.

## 8. Remaining boundaries

- The assistant inventory covers supported package managers and a curated common CLI set inside the active guest RootFS. It cannot enumerate every Android/Termux host package or arbitrary file in the system PATH. It reports this limitation rather than conflating host and guest state.
- PRoot still uses a shared writable RootFS and does not provide kernel-level isolation or restrict network access. This checkpoint does not add a read-only/disposable RootFS or network sandbox.
- Explicit MCP `tools/list` / `tools/call`, universal HTTP/API connectors, arbitrary native binary execution and all possible Skill capability types remain outside the current adapters.
- Public storage is a copy/export boundary, not a mounted Workspace. Project import and generic download synchronization into `Projects/` and `Downloads/` are not claimed as complete here.

## 9. Phase ordering and acceptance state

The user confirmed that Phase 13A–13D tests and an Android build had already succeeded before this Phase 13E follow-up. Their reports, test sources and historical runner scripts remain available for traceability, but no Phase 13A–13D test runner is invoked by the active Android build workflow. Phase 13E has its own focused preflight and runner; the runner targets only tests introduced for or explicitly covering Phase 13E, including an isolated package-ledger test rather than the prior Runtime Profile inheritance test. It also filters tool-catalog tests by the Phase 13E case name, so unrelated historical cases in the same test files are not rerun. Phase 13E itself is not accepted until its focused CI tests, ARM64 APK build, and phone validation close the checklist above. This does not imply that PRoot provides kernel isolation or that every Skill capability type is supported.
