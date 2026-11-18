# Phase 9 — Implementation Report

**Status:** Source implementation prepared; not formally accepted. Dart analysis, focused Flutter tests, Android ARM64 Release CI, and a real provider end-to-end run on an ARM64 phone have not yet been demonstrated for this revision.

## Delivered source changes

### Provider connector contract and registry

- Added `VideoProviderManifest` with schema-v1 YAML parsing, unknown-field rejection, constrained HTTPS origins, approved authentication header names/prefixes, model/capability declarations, safe request mappings, asynchronous submit/poll contracts, optional quote mapping, output-host allowlists, and bounded provider limits.
- Added `VideoProviderConnectorService` for list/inspect/install/update/remove, credential status, Workspace limits, async submit/poll, and result download.
- Provider manifests are declarative. The application does not execute a provider's downloaded code, Shell commands, scripts, or packages.
- Registry records use a workspace-scoped opaque identity derived from Workspace ID and public provider ID. Identical connectors can be installed independently into multiple Workspaces.
- Manifest files are stored below `.kelivo/video-providers/<provider-id>/`. Updates retain a backup copy and restore it if the manifest/registry update fails.

### Credentials

- Added `SecureVideoProviderCredentialStore` backed by `flutter_secure_storage`, with opaque hashed storage keys scoped to Workspace and provider.
- Added `MemoryVideoProviderCredentialStore` only for tests.
- Added a dedicated Workspace settings credential page. The API key is entered into a masked password field and is never exposed as a conversation tool parameter.
- No API key is copied into extension records, connector manifests, job metadata, permission arguments, or tool output.

### Async jobs and production workflow integration

- Added `video_provider` to the built-in tool catalog, reserved tool names, conversation routing, and Workspace tool-card presentation.
- Supports async submission, status polling, and controlled MP4 download for the manifest-declared text-to-video/image-to-video modes.
- Provider job metadata excludes prompt text, image URL, credentials, and provider output URL.
- The result downloader disables redirects, validates HTTPS/port/allowlisted host and public DNS results, enforces maximum size/content type, and checks the MP4 `ftyp` signature before import. DNS validation is a best-effort preflight, not IP-pinned resolution.
- `VideoProductionService.importProviderClip` saves the clip beneath `assets/generated/<provider-id>/<job-id>.mp4`, links it to an existing scene, updates the source manifest/storyboard, and invalidates prior render/export results.
- Provider choice is per submit call; local Phase 7 engine configuration is not modified.

### User limits and pricing

- Default local limits: 20 requests per UTC day, 2 concurrent active jobs, and 128 MiB per result.
- Users can adjust the daily request cap, concurrent job count, download ceiling, and optional daily cost budget.
- Positive cost budgets require a live quote endpoint with a matching currency. Invalid/missing quotes and mixed-currency reservations block submission rather than guessing a price.
- No real provider, commercial price, or supported model is claimed or bundled.

### CI and tests

- Added `video_provider_manifest_test.dart` and `video_provider_credential_store_test.dart`.
- Extended built-in tool catalog/name checks and Workspace chat UI coverage.
- Added `.github/ci/android-phase9-test-manifest.txt` containing 31 focused test files (29 retained from the previous manifest plus 2 provider-specific test files).
- Added `analyze_android_phase9.sh` and `test_android_phase9.sh`; the Android workflows now use these scripts.
- Extended the Android-only audit to check the Phase 9 manifest and seven named Android chat UI regression cases.

## Static verification performed in this preparation environment

The following checks were executed against this source revision before packaging:

- `bash -n` passed for `audit_android_only.sh`, `analyze_android_phase9.sh`, `test_android_phase9.sh`, `package_android_apk.sh`, and `capture_step.sh`.
- PyYAML successfully parsed `.github/workflows/android-build.yml`, `.github/workflows/pr-check.yml`, and the example provider manifest.
- `bash .github/scripts/audit_android_only.sh` passed, including Android-only target checks, ARM64-only Gradle ABI, four PRoot library checksums, Phase 9 test-manifest coverage, seven named chat UI regressions, and workflow/script wiring.
- All 31 entries in `.github/ci/android-phase9-test-manifest.txt` exist. The manifest retains all 29 Phase 7 focused regression files and adds the two provider-specific test files. All seven named chat UI regression test names are present.
- `package:Kelivo/...` imports were checked across the 15 changed/new Dart files; no missing package paths were found.
- The project archive was checked with `unzip -t` after creation and its SHA-256 was recorded in the delivery notes.

`dart` and `flutter` executables are not installed in this preparation environment. Therefore `dart analyze`, `flutter test`, Android ARM64 Release build, and device/provider end-to-end validation were **not run** and remain formal acceptance gates. Static checks do not imply Dart compilation or runtime success.

## Known limitations

- No bundled provider and no live endpoint has been tested; the example manifest uses reserved `example.com` domains only.
- OAuth, multipart uploads, provider job cancellation, webhooks, retries, and automatic connector discovery are not implemented.
- Provider quote responses are trusted according to the user-installed connector contract and are not independently validated against billing.
- Local daily and concurrency limits are app-level controls and are not a distributed quota lock across multiple devices.
- CI/Dart/Flutter/Android ARM64 and real-device acceptance remain pending for this revision.

## Acceptance state

The source-level Phase 9 feature set is prepared. Do not mark Phase 9 accepted, advertise a provider as verified, or advance to Phase 10 until the focused CI, Android ARM64 Release, secure credential isolation, and a real async generate → poll → download → scene asset workflow pass on an ARM64 device.
