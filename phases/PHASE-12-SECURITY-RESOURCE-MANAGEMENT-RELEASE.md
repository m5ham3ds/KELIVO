# Phase 12 — Security, Resource Management & Release Hardening

**Status:** Source implementation prepared; formal acceptance is pending Android CI, an ARM64 Release build and on-device validation. This phase strengthens extension permission review and performs a best-effort resource preflight before local engine rendering. It does not claim that PRoot is a kernel sandbox or that the current source snapshot is a store-ready signed release.

## Scope delivered

### Extension permission review

- Added `ExtensionPermissionPolicy` as a common permission catalogue for Skills, video engines and video providers.
- Permission declarations are deduplicated and sorted, then annotated with a risk level and a human-readable purpose.
- Recognized permissions always require explicit tool/Android approval; the policy does not itself grant execution rights.
- Unknown permission identifiers are marked `unknown` and `blockedUntilReviewed`.
- Engine/provider inspect and install responses include permission-review metadata.
- Skill inspection and post-install summaries read `metadata.kelivo.permissions` from `SKILL.md` and show declared risks. Invalid/missing frontmatter is surfaced as an unknown blocked declaration rather than treated as an implicit grant.
- Mutating tools continue to rely on the existing per-operation approval path. A permission declaration is not a substitute for runtime Android permission checks or operation approval.

### Secrets, paths and runtime boundary

- Provider API keys remain in `flutter_secure_storage`, with an opaque SHA-256 storage key derived from Workspace ID plus provider ID. They are not written into provider manifests, extension metadata or tool arguments.
- Engine setting validation continues to reject secret-like setting keys; commands receive only explicit non-secret settings through the existing namespaced environment contract.
- Existing Workspace path resolution, regular-file checks and symbolic-link rejection remain in force for engine and quality workflows.
- PRoot and Runtime Profiles are logical execution/path scopes inside the app process. They are **not** a kernel security boundary and must not be described as a hostile-code sandbox. Install only adapters and Skills from sources the user trusts.

### Android resource telemetry

- Added an Android native method channel `app.device_resources` and Dart `DeviceResourceMonitor`.
- The snapshot reads available/total RAM and Android low-memory state, app process PSS, app-process CPU utilization normalized per core, storage availability on the app-data volume, Android thermal status/headroom where supported, battery temperature and measurement time.
- Unsupported or failed measurements remain `null`. A missing snapshot is reported as `unknown`, not as a healthy device.
- The read-only `video_engine` action `resource_preflight` exposes the latest assessment to the conversation.
- `VideoRenderResourceGuard` warns at moderate pressure and blocks a new local render only on measured critical conditions. Current defaults: available RAM below 256 MiB or Android low-memory state; available storage below 768 MiB; Android thermal status severe or worse / headroom at least 1.0; battery temperature at least 48 °C. Warning thresholds include RAM below 768 MiB, storage below 2 GiB, thermal status moderate/headroom at least 0.8, battery at least 43 °C, and app process CPU at least 90% of one core.
- Unknown telemetry does not block by itself. The assessment includes recommendations to close apps, free storage, reduce output resolution, wait for cooling, or use cloud rendering.
- The guard is evaluated inside `VideoEngineService.render`, so both `video_production` and `video_hybrid_workflow` inherit the preflight when they delegate to an engine.

### Release and network posture

- Added `release_hardening_audit.sh` and invoke it from the Android-only source audit.
- The audit checks ARM64-only ABI configuration, Android backup-off policy, exclusion of private signing files, secure provider credential storage, resource telemetry channel registration and explicit GitHub Actions permissions.
- `.gitignore` now excludes `android/key.properties` and common keystore formats.
- The Gradle Release variant still uses the debug key when no private upload keystore is supplied. This is an installable CI/test artifact only; it is **not** evidence of a public-store signing configuration. A production release must supply a private upload key outside source control and verify the final APK signature.
- **Cleartext compatibility exception:** `android:usesCleartextTraffic="true"` remains enabled. Existing code paths include HTTP Ubuntu/PRoot mirrors and localhost OAuth callbacks, and the app also accepts user-provided HTTP media/service URLs. Turning the flag off globally without a network/security-config migration can break existing functions. This broad exception increases network exposure on untrusted networks and remains a release blocker to review. It is documented rather than silently changed. Video-provider connector manifests still require HTTPS for remote API endpoints; this does not make every other app HTTP path HTTPS-only.
- No credentials, signing keys or generated APK are included in this source ZIP.

## Focused regression coverage

- `device_resource_monitor_test.dart` covers telemetry parsing, malformed values, unknown state, ready/warning/blocked thresholds, thermal status, battery temperature, storage and CPU warnings.
- `extension_permission_policy_test.dart` covers sorting/deduplication, risk classification, unknown blocked permissions and absence of implicit grants.
- Existing built-in tool catalog coverage asserts the read-only `resource_preflight` action is exposed.
- Skills install output now includes the same permission review shown by `extension_inspect`.

## CI scope

- The initial CI manifest was intentionally retired from the automatic release path after the Arabic build attempt showed that the accumulated Phase regression suite was excessive for the localization fix.
- The streamlined release workflow now runs only ARB key/placeholder parity, `flutter gen-l10n`, the Arabic RTL widget test and the persisted Arabic locale test before building the ARM64 APK.
- The Android-only audit checks the two required localization tests and runs `release_hardening_audit.sh`.
- The focused job does not replace full project validation or on-device release testing.

## Acceptance criteria

1. The Arabic RTL widget test and persisted locale test pass in GitHub Actions.
2. Android ARM64 Release APK builds and is installable on a real ARM64 phone.
3. `resource_preflight` returns valid measurements on supported Android versions and gracefully reports unavailable thermal/CPU data where APIs do not expose it.
4. A simulated critical resource snapshot blocks the next local render before any engine command starts; warning/unknown snapshots do not silently change project settings.
5. A real long-running render is measured on the target phone, and the user verifies the warning/block thresholds do not cause unreasonable false positives or missed thermal events.
6. Skill, engine and provider permission reviews show the declared risk and never grant permissions implicitly; unknown permission IDs remain blocked.
7. Provider credentials remain Workspace-scoped in Android secure storage and do not appear in exported manifests, shell arguments or logs.
8. The final APK is signed with a user-controlled private upload key for a public release, its signature is verified, and the cleartext compatibility exception is either removed through a tested network migration or explicitly accepted as a documented residual risk.
9. Broader chat, Skills, MCP, PRoot, Workspace and media-production regression tests remain available for dedicated validation runs; they are not part of every ARM64 release build.

## Explicit limitations and remaining work

- No Dart/Flutter SDK, Android SDK/Gradle toolchain or target phone was available in the source-preparation environment. Dart formatting/analyzer, Flutter tests, Kotlin/Gradle compilation, APK build/install/startup timing and device thermal/load tests are **not claimed as executed**.
- Resource readings are best-effort snapshots. CPU is the Kelivo app-process CPU time sampled between calls, not a whole-device CPU gauge and not the CPU time of separate PRoot child processes; PSS is also for the app process only. Storage is filesystem availability on the app-data volume; thermal APIs vary by Android version and manufacturer.
- A critical snapshot prevents starting a new engine render. The app does not suspend/resume an already-running generic engine process, and it does not silently lower a project's resolution. Generic engines expose no stable pause/resume/reconfigure contract yet. Recommendations are returned for user-directed action.
- Long-running tasks are not made resumable after process death by this phase. Existing process records/recovery hints remain as previously documented; full checkpoint/resume is still needed.
- HTTP cleartext is globally enabled for compatibility. This is a known security trade-off and should be narrowed in a dedicated migration before public release.
- PRoot and Runtime Profiles do not isolate arbitrary hostile code at kernel level.
- Earlier Phase 3–11 acceptance gates remain pending where documented. Phase 2 remains the only phase with supplied successful CI and ARM64 Release acceptance evidence. Phase 12 is not formally accepted until its CI/build/device criteria pass.
