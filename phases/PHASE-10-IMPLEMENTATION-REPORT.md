# Phase 10 — Implementation Report

**Status:** Phase 10 source implementation prepared; not formally accepted. Dart analysis, focused Flutter tests, Android ARM64 Release build, and a real mixed code/provider render on an ARM64 phone have not been demonstrated for this revision.

## Delivered source changes

### Hybrid workflow contract

- Added `HybridWorkflowSpec` and `HybridSceneRoute` with strict IDs, supported modes, exactly one route per scene, unique Skill IDs, bounded scene count, target profile validation and explicit audio policies.
- The saved recipe contains only routing and execution metadata. It does not accept executable code, API keys or persisted provider image URLs.
- Configuration inspects that referenced engines/providers are installed, validates the declared scene/assembly capabilities and provider model selection, and reports only Boolean credential presence plus engine-preflight-pending IDs.
- The saved recipe tracks scene state, attempts, provider job IDs, output asset paths and provenance, along with the assembly target and normalization intent. It also pins each referenced engine/provider manifest by version and SHA-256 digest; run, poll, download and assembly re-inspect those pins and require reconfiguration if a dependency drifts. Provider submit/poll/download also pass the expected version/digest into the connector action for an in-operation recheck.

### Engine capability contract

- Extended `kelivo.engine.yaml` parsing with explicit `capabilities.sceneRendering`, `capabilities.hybridAssembly` and `capabilities.acceptsMp4Assets` flags.
- All capabilities default to `false` for existing engine manifests. `hybridAssembly: true` is invalid unless `acceptsMp4Assets: true` is also declared.
- A code-scene route requires an adapter declaring `sceneRendering` and MP4 output. Final assembly requires `hybridAssembly`, `acceptsMp4Assets` and MP4 output.

### Per-scene execution and assembly

- Added `VideoHybridWorkflowService` with `plan`, `configure`, `status`, `run_scene`, `poll_scene`, `download_scene`, `assemble` and `export` actions.
- Code scenes use a temporary single-scene project under `.kelivo/hybrid-staging/`, render through the selected Phase 7 adapter, verify the engine output location and MP4 signature, then import the clip into the target scene.
- Provider scenes reuse Phase 9 asynchronous submit/poll/download for text-to-video and image-to-video. Image URLs are transient; provider output is imported into the assigned scene using the existing guarded downloader and credential isolation.
- Assembly is blocked until all scenes are complete and the selected adapter explicitly declares the required hybrid capabilities. The assembly adapter receives the complete project metadata, routes, generated scene assets and normalization target.
- Export delegates to the Phase 8 source/MP4 export path.

### Project integrity and recovery

- Added a source fingerprint covering the normalized production brief, storyboard, declared source files and user-supplied scene assets. Generated `assets/generated/` outputs are excluded so a completed scene does not invalidate the same workflow.
- Project mutations to the brief/source/assets require reconfiguration before additional workflow operations.
- Missing project files, unsafe source paths, symbolic links, unsupported output roots, invalid MP4 signatures and oversized generated files are rejected.
- Prior render/export metadata is invalidated when a scene clip is imported. Failed scenes require an explicit retry flag; active and completed scenes are not normally resubmitted.
- Tightened the staged-scene prompt fallback so a scene with no local prompt or description inherits the project prompt rather than producing an invalid staged project.

### Conversation integration

- Registered `video_hybrid_workflow` in the built-in tool catalog, reserved tool-name set and Workspace tool handler.
- Mutating actions (`configure`, `run_scene`, `download_scene`, `assemble`, `export`) request explicit approval. Plan/status/poll use the existing workspace permission check.
- Added a dedicated chat timeline card and UI regression for the hybrid workflow tool.

### Tests and CI

- Added `hybrid_workflow_spec_test.dart` for mixed routes, exact per-scene coverage, invalid route modes/IDs, duplicate Skill IDs, invalid output profiles/audio policy and immutable dependency-pin matching/malformed-pin rejection.
- Extended `video_engine_manifest_test.dart` to cover the explicit hybrid capabilities, backward-compatible defaults and invalid capability combinations.
- Extended built-in tool catalog/name tests and chat UI coverage.
- Added `.github/ci/android-phase10-test-manifest.txt`, `analyze_android_phase10.sh` and `test_android_phase10.sh`.
- Updated Android build and PR-check workflows to use the Phase 10 focused analyzer/test scripts.

## Static verification in this preparation environment

The following checks were performed before packaging:

- `bash -n` passed for the new Phase 10 analyzer/test scripts and the existing Android audit/package scripts.
- YAML parsing passed for both GitHub workflow files and the engine/provider example manifests.
- The Android-only audit passed with the Phase 10 manifest, engine/provider/tool UI wiring and Android ARM64 configuration.
- All entries in `.github/ci/android-phase10-test-manifest.txt` exist, and all eight named chat UI test cases are present.
- No Dart or Flutter executable is installed in this preparation environment. Therefore `dart format`, `dart analyze`, `flutter test`, the Android ARM64 Release build and device-level hybrid render were not run.
- The final ZIP was checked with `unzip -t` and its SHA-256 recorded in the delivery message.

## Known limitations

- No actual engine/provider pair was exercised on a device. The phase cannot be described as end-to-end verified.
- The final assembly engine is responsible for honoring dimensions, FPS, timing and audio policy. The application stores the profile and checks declared capabilities, but codec/frame/audio verification belongs to Phase 11.
- MP4 `ftyp` signature validation does not prove that a clip is complete or decodable.
- Skill IDs are recorded as planned collaborators only. Actual Skill execution and artifact handoff remain blocked by the unresolved Phase 4 executor gap.
- Parallel scene scheduling, full cancellation/recovery for engine processes, preview and per-frame progress are deferred.
- Existing Phase 3–9 acceptance gates remain pending where recorded. Phase 2 remains the only later milestone with demonstrated Android ARM64 CI/build acceptance in the supplied project history.

## Acceptance state

Phase 10 source work is prepared. Do not mark Phase 10 accepted or claim a verified mixed-video workflow until the Phase 10 focused CI, Android ARM64 Release build, and on-device code scene + provider scene + hybrid assembly + export all pass. The output must then pass Phase 11 media QA before it is described as production-verified.
