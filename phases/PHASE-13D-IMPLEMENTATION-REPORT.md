# KELIVO Phase 13D — Secure Execution & Acceptance

**Checkpoint date:** 2026-11-10  
**Project baseline:** `1.3.4+84`  
**Status:** Source checkpoint prepared; **not accepted**. Flutter tests, CI, ARM64 APK build and phone acceptance were not run in this environment.

## 1. Scope and outcome

This checkpoint hardens the existing Android PRoot Skill execution path. It does not claim that PRoot is a security sandbox, and it does not introduce a read-only/disposable RootFS or network isolation. Those are material unresolved risks, not implementation details to hide.

### Mandatory per-run human approval

- `skill_execute` always requests a fresh manual approval for every invocation, including when the conversation is in Full Access mode.
- A previous one-time approval cannot satisfy a later Skill execution approval.
- The Skill approval card does not show a shortcut to switch the conversation to Full Access.
- `runtime.rootfs.write` is now a critical permission in the permission review, alongside the existing runtime, shell, network, package, Workspace and external-service permissions.
- The approval payload intentionally contains only the Skill ID, declared entry point, Runtime Profile ID and input/output/argument counts. It omits raw argv, task text, input values and input file paths so pending approval state does not retain those values unnecessarily.
- The approval card has localized Arabic, English, Simplified Chinese and Traditional Chinese warnings. It tells the user that the active RootFS is shared and writable, network access is unrestricted, and PRoot is not kernel-level isolation.

### Guest environment and output handling

- Skill execution no longer forwards user-defined Runtime Profile environment variables. It passes only the small interpreter/bootstrap allowlist synthesized for the selected profile.
- On Android, `ProotCommand` builds the guest environment under `/usr/bin/env -i`; only the explicit request environment is added to the guest process. Android host process variables are not copied into the guest environment.
- Raw argv values are not emitted in the execution report; the report includes only argument count and a SHA-256 digest.
- Captured stdout/stderr is scrubbed for known invocation values, values under credential-like input keys, common credential assignment labels, Bearer strings and common provider token shapes.
- Approval state omits raw inputs and paths. Redaction is best-effort and cannot identify every possible secret or arbitrary encoding in process output.

### Staged host data and remaining PRoot risk

The existing executor continues to mount a per-run staged Skill snapshot and its staged I/O directory only. It does not attach the live installed Skills tree, the full Workspace root, chat files, or configured external mounts. It verifies source digests and declared outputs as implemented in earlier checkpoints.

**Important unresolved boundary:** the PRoot process still uses the active, shared, writable RootFS. An approved Skill can modify system files or installed packages and affect later runs. PRoot does not restrict device network access and does not provide a kernel sandbox. This checkpoint must not be represented as safe isolation for arbitrary untrusted Skills. No read-only RootFS, disposable per-run RootFS, kernel sandbox, network namespace/firewall policy, or explicit secret-grant mechanism is implemented.

## 2. Source files changed

- `lib/core/services/skills/skill_execution_security.dart` — runtime environment allowlist, sensitive-value collection/redaction and explicit boundary descriptors.
- `lib/core/services/skills/skill_executor.dart` — requires an acknowledged shared-RootFS risk, verifies critical execution permissions, filters the guest environment and redacts report output.
- `lib/core/services/runtime_profiles/runtime_profile_service.dart` — excludes custom Runtime Profile environment values from third-party Skill execution.
- `lib/core/services/conversation_tool_permissions.dart` — enforces manual per-run approval even under Full Access and prevents prior one-time approval from bypassing it.
- `lib/core/services/extensions/extension_permission_policy.dart` — adds critical `runtime.rootfs.write` permission review.
- `lib/features/home/services/tool_handler_service.dart` — requires manual approval and keeps raw task/argv/input values and paths out of pending approval payloads.
- `lib/core/services/extensions/skill_execution_tools.dart` and `lib/core/services/skills/skills_prompt.dart` — document actual execution and trust limitations.
- `lib/features/chat/widgets/workspace_tool_ui.dart` — localized, visible RootFS/network/PRoot warning in the Skill approval card; hides the Full Access shortcut for this tool.
- `android/app/src/main/kotlin/com/psyche/kelivo/workspace/ProotCommand.kt` — clarifies the shared writable RootFS semantics at the `-r` argument.
- Focused tests under `test/core/services/skills/`, `test/core/services/`, and `test/features/chat/widgets/`.
- `.github/scripts/run_phase13d_execution_security_tests.sh` and `.github/workflows/android-build.yml` — focused Phase 13D test gate.
- Phase 13 plan, master plan, and `phases/README.md` — updated checkpoint state and limitations.

No dependency, Flutter, Dart, Gradle, AGP, Kotlin, NDK, or application-version changes were made. `pubspec.yaml` and `pubspec.lock` remain untouched.

## 3. Focused tests added or extended

- Runtime environment allowlist excludes custom credential-like profile variables.
- Known argv values and values beneath sensitive input keys are redacted from captured output.
- Common credential environment labels and Bearer/provider token patterns are redacted while normal output remains visible.
- Boundary descriptor states the shared writable RootFS, unrestricted network, absent kernel sandbox and staged-only Workspace binding.
- Skill executor tests (run once through the existing Phase 13B runner) cover missing risk acknowledgement, incomplete critical permission review, exit failure, timeout, cancellation, missing interpreter and output tampering, alongside existing digest/staging/output checks.
- Permission tests ensure Full Access and prior one-time approvals do not bypass a mandatory new Skill approval.
- Arabic UI test checks that the approval card visibly displays the shared RootFS/network warning, has Allow/Deny actions and offers no Full Access shortcut.
- CI runs only the focused Phase 13D security/executor/permission/UI tests; broad regression suites were not reintroduced.

## 4. Local validation and limitations

See `../build-report/PHASE-13D-LOCAL-DIAGNOSTICS.md` for exact commands and results. Bash syntax, Android-only/release-hardening audits, localization parity, ARB JSON parsing and workflow YAML parsing passed. Flutter/Dart/Gradle were unavailable, so Dart formatting/analyzer, Flutter tests, `pub get`, Android/ARM64 APK build and device validation were not run. Registering the CI test step is not evidence that CI has passed.

## 5. Acceptance checklist — must be completed before proceeding

1. Run the focused Phase 13A–13D CI tests and review actual logs; do not infer success from the YAML or local static checks.
2. Build and install the Android ARM64 APK using the project’s pinned CI toolchain; preserve the `1.3.4+84` baseline.
3. Verify that every Skill invocation requests a new manual approval even in Full Access mode, and denial starts no script process.
4. Use a harmless test Skill that prints a supplied argv value and a value from a credential-named input field; verify reports and pending approval state do not expose those values.
5. Verify custom Runtime Profile variables are absent from the guest process while interpreter bootstrap variables remain functional.
6. Inspect the live installed Skill and Workspace trees before and after a harmless run; verify the run operates on its staged copy and external mounts block execution.
7. Verify timeout, cancellation, exit-code failure, output-path/type/size verification and retry behavior on device.
8. Review the active RootFS state after a harmless Skill run. Do not test destructive system mutation on a daily-use environment. The shared RootFS and unrestricted network remain accepted risks only after a deliberate product/security decision.
9. Verify existing Skill Pack install/update/rollback and `/youtube` behavior remain intact.

## 6. Phase ordering and acceptance state

The user directly requested preparation of source checkpoints for 13B, 13C and 13D while earlier acceptance gates remained open. This report records that authorization; it does not retroactively accept 13A, 13B or 13C. Their gates remain open, and Phase 13B still lacks the explicit MCP `tools/list` / `tools/call` adapter. Phase 13D is also not accepted. No phase after 13D should start until CI, ARM64 build, phone acceptance and an explicit RootFS/network security review close the Phase 13A–13D gates.
