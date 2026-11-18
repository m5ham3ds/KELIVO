# KELIVO — Phase 13B Implementation Report

**Phase:** 13B — Skill Executor & Tool Dispatch  
**Project baseline:** `1.3.4+84`  
**Implementation date:** 2026-11-10  
**Status:** Script-execution foundation implemented in source; **Phase 13B is not accepted or complete**. The focused Dart/Flutter tests, Android ARM64 Release build, and on-device execution checks have not been run in this environment. The explicit MCP adapter item from the architecture plan remains open.

## 1. Scope implemented in this delivery

This delivery adds an explicit `skill_execute` built-in tool for exact Python, Bash, and Node.js entry points declared as `local_script` capabilities in the Phase 13A import manifest. It does not turn Skill folders, `tools/`, binaries, workflow files, MCP server declarations, or HTTP/API connector declarations into executable commands.

The dispatcher:

1. Resolves the requested Skill only from the currently enabled assistant/conversation scope.
2. Rebuilds a one-Skill composition plan on the server; model-supplied DAG-completion assertions are not accepted.
3. Requires a complete Phase 13A import manifest and verifies the source/file snapshot before dispatch.
4. Requires an extension Runtime Profile whose `ownerId` exactly matches the Skill. The current implementation is Android PRoot-only.
5. Presents per-run approval, including the declared/required permission review and the actual PRoot trust boundary.
6. Copies a verified source snapshot into a UUID-scoped run directory and copies explicitly supplied workspace files into the input directory. The live Skills, chat and workspace trees are not mounted into the third-party process.
7. Executes an individually quoted argument vector through only `python3`, `bash --noprofile --norc`, or `node`; entrypoints are resolved only from the manifest and the declared `local_script.entryPoints` list.
8. Enforces time, input, snapshot, captured output, output file and aggregate output limits; validates the entire output tree (including undeclared files, symlinks and non-regular entries), file type/signature where supported, aggregate sizes, and SHA-256.
9. Records successful DAG stages in the app-local extension entity store. Later stages must verify prior stage records, source digests, expected output presence, output size/hash, and exact artifact input paths. The model cannot supply a fake `completed_skill_ids` list.
10. Keeps output artifacts under `.kelivo/skill-execution/` while removing the staged source/input/tmp data after a successful run. Failed runs are discarded.

## 2. Security decisions and limitations

- **PRoot is not a kernel sandbox.** It shares device network access and cannot by itself provide kernel-enforced memory, process, or filesystem isolation. Every run is explicitly approved and the implementation reports `networkRestricted: false` and `kernelSandbox: false`.
- The process receives one writable mount: its UUID-scoped run directory at `/run/kelivo-skill`. Configured external mounts cause execution to be refused. The live Skills directory, chat directory and general workspace are not mounted.
- Runtime Profile filesystem roots remain in the PRoot root filesystem. Only one process per Skill owner may run at once, even if multiple Runtime Profiles exist for that Skill; each Runtime Profile is also serialized. Ledger writes are queued to prevent concurrent DAG records from overwriting each other.
- Raw argv values are omitted from model-visible execution results; an argument count and SHA-256 audit value are returned. Common labelled secrets and common bearer/provider token patterns are redacted from captured stdout/stderr. Raw command-line values are not returned. This is best-effort output redaction, not a guarantee that arbitrary unlabelled secrets cannot be printed by a third-party script.
- Unknown output file types are recorded as `application/octet-stream` with `extension_only_unclassified`; they are not represented as having passed content inspection. Known formats receive extension/signature or content checks.
- The tool does not install dependencies, run `postinstall`, launch MCP servers, call HTTP/API connectors, execute native binaries, or run workflow definitions. Phase 13A repository-shared resource bundles remain separately stored and are **not mounted or copied into script runs in this checkpoint**; scripts that require those resources must not assume they are available.
- **Open Phase 13B item:** the architecture plan also calls for explicit MCP adapters. That adapter and the MCP `tools/list`/`tools/call` lifecycle are not included in this delivery. Existing MCP configuration and provider functionality is left unchanged; a filename or `tools/` directory is never treated as permission to start a server.
- Stronger per-process network restrictions, secret injection controls, Android-side mount restrictions and a dedicated security acceptance pass remain Phase 13D work. The current implementation must not be described as a secure kernel sandbox.

## 3. Source files changed

- `lib/core/services/skills/skill_executor.dart` — typed Skill snapshot executor, exact local-script entrypoint validation, PRoot-only invocation, bounded I/O, output verification, stage ledger and structured result.
- `lib/core/services/extensions/skill_execution_tools.dart` — `skill_execute` schema and execution boundary description.
- `lib/core/services/runtime_profiles/runtime_profile_service.dart` — Skill-owned extension profile resolver and serialized Skill runs.
- `lib/core/services/runtime_profiles/runtime_profile_models.dart` — shell ecosystem support for Bash Runtime Profiles.
- `lib/core/services/runtime_profiles/runtime_profile_tools.dart` — shell ecosystem schema/documentation.
- `lib/core/services/extensions/extension_permission_policy.dart` — external-services permission risk category.
- `lib/core/database/extension_entity_store.dart` — app-local Skill execution ledger entity kind.
- `lib/core/services/tools/built_in_tool_catalog.dart` — tool registration.
- `lib/features/home/services/built_in_tool_names.dart` — built-in name reservation.
- `lib/features/home/services/tool_handler_service.dart` — scoped selection, server-side composition, permission approval and execution dispatch.
- `lib/features/chat/widgets/workspace_tool_ui.dart` — execution tool label/icon.
- `lib/core/services/skills/skills_prompt.dart` — model instructions for the approved executor and its boundaries.
- `test/core/services/skills/skill_executor_test.dart` — focused executor, mount, manifest, ledger, traversal, digest, MIME, argument-redaction and profile-serialization tests.
- `.github/scripts/run_phase13b_executor_tests.sh` — narrow Phase 13B regression runner.
- `.github/workflows/android-build.yml` — captured Phase 13B test step after dependency resolution and Phase 13A tests.

## 4. Tests added / intended CI coverage

The new focused CI runner invokes only:

- `test/core/services/skills/skill_executor_test.dart`
- `test/core/services/runtime_profiles/runtime_profile_models_test.dart`
- `test/core/services/runtime_profiles/runtime_profile_service_test.dart`
- `test/core/services/tools/built_in_tool_catalog_test.dart`

The executor tests cover:

- Exact declared script execution from a verified snapshot and app-local completion ledger.
- The process receives only the one invocation mount, not the original Skill tree or workspace mounts.
- Model-asserted completion of a predecessor stage is rejected without a ledger record.
- Path traversal is rejected before process dispatch.
- A tampered source file is rejected by manifest size/hash checks.
- Expected output MIME mismatch is rejected and output is not committed to the ledger.
- Symlinks anywhere in the output tree are rejected and never added to the ledger.
- Raw argv values do not appear in the result, and common labelled secrets in output are redacted.
- Concurrent execution on the same Skill Runtime Profile is refused.

## 5. Verification performed in this delivery environment

- Source-level inspection and targeted cross-reference checks were performed.
- `bash -n` passed for the focused Phase 13A/13B runners and the Android/release audit scripts.
- `.github/scripts/audit_android_only.sh` passed.
- `.github/scripts/release_hardening_audit.sh` passed; its existing debug-key fallback remains a documented test-artifact limitation when no private upload keystore is configured.
- Arabic localization key/placeholder parity passed: 4,733 messages, 4,614 Arabic translations and 119 English fallbacks.
- The GitHub Actions workflow YAML parsed successfully and contains the expected Android ARM64 build and build-report jobs.
- Project version remains `1.3.4+84`; `pubspec.yaml`, `pubspec.lock`, Gradle and AGP versions were not changed.
- The CI workflow now includes the focused Phase 13B runner.
- **Not run:** `dart format`, `dart analyze`, Flutter tests, Gradle tasks, Android ARM64 Release build, APK installation, or actual Android PRoot script execution. Flutter, Dart and Gradle executables were not available in this environment.
- Therefore no test, analyzer, or APK success is claimed. The new Dart tests are pending execution in GitHub Actions.

## 6. Acceptance gates before Phase 13C

1. GitHub Actions must run the Phase 13A and Phase 13B focused suites successfully.
2. Run Dart formatting/analyzer checks using the project's pinned Flutter/Dart toolchain, and resolve every compile/analyzer/test failure attributable to this phase.
3. Build the Android ARM64 Release APK and install it on the phone.
4. In a disposable workspace, install a test Skill with a declared harmless script, inspect its import report, create the correct extension Runtime Profile, approve one run, and verify output SHA-256 and the execution record.
5. Verify a denied approval, unsupported entrypoint, missing profile, wrong-owner profile, missing interpreter, timeout/cancellation and modified source all fail closed.
6. Verify a two-Skill artifact chain cannot run the second Skill until the first output is recorded and its path/size/hash are revalidated; modify the prior artifact and confirm the downstream run is blocked.
7. Confirm existing `/youtube`, MCP tools, normal workspace shell tools, Skill Pack update/rollback and ordinary chat remain unaffected.
8. Implement and test the explicit MCP adapter lifecycle (`tools/list` then `tools/call`) before declaring the complete Phase 13B scope done. Do not start arbitrary `tools/` directories.

**Conclusion:** The typed local-script executor and dispatch path are present in source, but this is an implementation checkpoint, not an acceptance claim. Phase 13A remains acceptance-pending; Phase 13B remains open for CI/device validation and the explicit MCP adapter item. Phases 13C and 13D were not started.
