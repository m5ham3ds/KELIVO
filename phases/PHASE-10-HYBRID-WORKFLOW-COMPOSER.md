# Phase 10 — Hybrid Workflow Composer

## Objective

Compose a single video project from scenes produced by different routes: a local/code engine for some scenes and an installed AI video provider for others. The workflow remains renderer-neutral until the user selects an explicitly compatible Phase 7 assembly adapter.

## Architecture and contracts

- `video_hybrid_workflow` is the conversation-first control surface. It validates, configures, runs and tracks a reproducible hybrid workflow for an existing `video_production` project.
- Every production scene must have exactly one route. A route is either `code` with one `engine_id`, or `provider` with one `provider_id` and optional model. Invalid, missing, duplicate, or mixed routes are rejected.
- Code-scene adapters must explicitly declare `capabilities.sceneRendering: true` in `kelivo.engine.yaml`. This means the adapter accepts a staged Kelivo project containing exactly one production scene and emits a verified MP4.
- The final assembly adapter must explicitly declare both `capabilities.hybridAssembly: true` and `capabilities.acceptsMp4Assets: true`, and use `outputExtension: mp4`. A legacy adapter with no capabilities is not assumed to support hybrid operations.
- Provider scenes reuse the Phase 9 asynchronous submit → poll → download flow, including text-to-video and image-to-video (an image URL can be supplied transiently for a scene). The provider output is imported as a local scene asset; its output URL, prompt, image URL and API key are not persisted in the hybrid recipe.
- The recipe stores scene routing, provider/model or engine IDs, immutable dependency pins (manifest version + SHA-256 digest for every engine/provider), Skill IDs selected by the user, normalization target (width, height, FPS and MP4), audio policy, per-scene state/attempt metadata and provenance. Before each scene execution, provider poll/download and final assembly, KELIVO re-inspects the selected dependency and refuses to continue if its pinned version or digest changed. Provider submit/poll/download pass those expected pins into the connector operation itself, so the connector verifies the manifest again immediately before using it. No executable code or credentials are accepted in the recipe.
- The source project receives a stable source fingerprint. Changes to the project brief, storyboard, source files or user assets invalidate the saved workflow and require reconfiguration. Generated scene clips are excluded from that fingerprint so completing a scene does not invalidate the recipe itself.
- Code-scene inputs are copied to a temporary single-scene workspace under `.kelivo/hybrid-staging/`. The staging workspace is removed after the render attempt. Outputs are accepted only from the selected engine's private output directory, must be MP4 files with an `ftyp` signature, and are copied into the project as generated assets.
- Assembly runs against the full production project after every scene is completed. The selected adapter is responsible for applying the saved normalization and audio policy. KELIVO records the declared target, but does not claim codec-level, frame-accurate, duration or audio QA; those checks belong to Phase 11.
- Workflow mutations, code execution, provider submissions/downloads, assembly and export require user approval. Read-only plan/status/poll operations use the existing workspace permission check. Status exposes dependency version/digest pins, never credentials.
- Skill IDs can be recorded as intended collaborators. Actual Skill execution and file handoff remain unavailable until the outstanding Phase 4 Skill executor is implemented; the composer does not pretend otherwise.

## Conversation actions

The `video_hybrid_workflow` tool supports:

- `plan`: validate complete per-scene routing and show target profile/capability requirements without saving or running anything.
- `configure`: verify that each referenced engine/provider is installed, validate the declared scene/assembly capabilities and selected provider model, report credential presence without exposing values, then save the reproducible workflow to the selected production project. Engine preflight is reported as pending and is not silently executed during configuration.
- `status`: report workflow and per-scene state.
- `run_scene`: render one staged scene with a declared scene-capable engine or submit an asynchronous provider job.
- `poll_scene`: check the provider job status.
- `download_scene`: import the completed provider MP4 into its scene.
- `assemble`: render the complete project with the selected hybrid-assembly engine after all scenes are complete.
- `export`: package the final MP4 and source project using the Phase 8 export path.

## Validation and safety

- IDs and route cardinality are validated; route configuration is capped at 120 scenes and 12 Skill IDs per scene.
- Target dimensions, FPS, duration and audio policy are validated against bounded ranges and the existing production spec.
- Provider secrets remain in the Phase 9 secure credential store. Transient image URLs are forwarded only to the selected provider submission and are not saved by the hybrid workflow.
- Missing project files/assets block configuration or assembly. Unsafe paths, symlinks, outputs outside the selected engine output root, non-MP4 outputs and over-limit files are rejected.
- Generated assets are written through temporary files and atomic rename where possible. Prior render/export metadata is invalidated after scene assets change.
- A failed scene requires an explicit `retry: true` before rerunning. Active/completed scenes cannot be accidentally submitted twice through the normal state check.
- PRoot and Workspace path checks are logical isolation controls, not a kernel security sandbox. User-approved engines run with the permissions of the configured runtime.

## Focused tests and CI

- `.github/ci/android-phase10-test-manifest.txt` retains the focused Phase 3–9 Android regressions and adds hybrid route/spec validation.
- The focused UI set includes dedicated cards for the engine, production, provider and hybrid workflow tools.
- GitHub Actions uses `analyze_android_phase10.sh` and `test_android_phase10.sh`, followed by the Android ARM64 APK build.

## Acceptance criteria

1. A project with code and provider scenes accepts exactly one valid route per scene and rejects missing, duplicate or mixed routes.
2. Code scenes can run only on an adapter declaring `sceneRendering`; a legacy adapter without that capability is rejected.
3. Provider scenes use Phase 9 asynchronous jobs and can be polled/downloaded into their assigned scenes without exposing credentials or output URLs.
4. A hybrid assembly adapter is accepted only when it declares `hybridAssembly`, `acceptsMp4Assets`, and MP4 output.
5. The assembled project retains the per-scene route recipe, source files and generated-asset provenance and exports MP4 plus source ZIP.
6. Source changes invalidate the configured recipe; generated scene outputs do not invalidate the recipe while the run is progressing.
7. Focused Dart analysis/tests and Android ARM64 Release CI pass.
8. On an ARM64 Android device, at least one actual code scene and one actual provider scene are generated, assembled by a compatible adapter, and exported into one playable MP4 with source archive.
9. Phase 11 quality checks confirm actual dimensions, frame rate, duration, codec, audio policy and playback before the workflow is advertised as production-verified.

## Deferred / explicit limitations

- No engine, provider, model or Skill is bundled or preselected.
- The phase does not provide a codec-level normalization implementation. The assembly adapter must implement the saved target profile and audio policy; Phase 11 must inspect the result.
- Skill IDs are recorded only; the Phase 4 Skill executor and artifact handoff are still outstanding.
- Preview, per-frame progress, parallel scene scheduling, cancellation of in-flight code engine processes, provider cancellation, cross-device locks and automatic route selection are not implemented.
- MP4 `ftyp` validation proves only a container signature, not that the file is complete, decodable or playable.
- No real provider/engine combination is claimed as tested. CI, ARM64 build, device end-to-end and QA acceptance remain pending.
