# Phase 13E corrective implementation — Chat ↔ Android PRoot bridge

**Date:** 2026-11-12  
**Status:** Source correction prepared; focused Flutter tests and Android ARM64/device acceptance remain pending.

## User-observed failure

The Environment screen reported Ubuntu 24.04.3 (PRoot) as `Installed` and `Ready`, but an unbound chat could invoke `environment_status` and still receive/produce an answer that treated Ubuntu as unavailable, guessed the handset model, and did not execute a command in the guest.

This was not evidence that Ubuntu or PRoot had to be reinstalled. It was a chat tool-context and runtime-bridge defect.

## Root causes confirmed in source

1. `MessageGenerationService` used `WorkspaceToolsService.resolve()` for explicitly selected projects. When no project was bound, the fallback was `_skillsOnlyContext`; this context intentionally exposed only skill-file reading and did not provide Shell or Skill execution.
2. A conversation-scoped scratch workspace was not represented in `WorkspaceProvider`. `WorkspaceToolsService._enabled()` delegated to `WorkspaceProvider.byId(syntheticChatId)`, which returned `null` and disabled every workspace tool.
3. `ToolCallPermission` was given the synthetic scratch-workspace ID. The persisted conversation permission state correctly stores no project workspace ID, so the check returned `context_changed`.
4. Runtime references could be captured before the asynchronous native PRoot initialization completed. RootFS UI state by itself is not proof that the process-wide runtime is registered or that a guest command can run.
5. The model-facing environment report did not provide a sufficiently authoritative, explicit bridge-availability contract for the assistant to distinguish RootFS installation, PRoot host readiness, a live guest session, and workspace tool availability.

## Changes

### 1. Private conversation workspace

- An Android conversation with no explicit project binding now receives a private scratch workspace under app-private storage.
- The workspace path is deterministic per conversation via a SHA-256 digest, and does not reuse a user-selected project directory.
- It mounts only `/workspace`, `/chat`, `/skills`, and `/tmp`; it does not inherit SAF/external folder mounts.
- The context is ephemeral and never writes the synthetic workspace ID into conversation extras or `WorkspaceProvider` metadata.
- If a project binding exists but is stale/invalid, KELIVO does not silently replace it with a scratch workspace.

### 2. Correct tool gating and permission binding

- Conversation-scoped tools use their in-memory `Workspace` enablement rather than querying `WorkspaceProvider` for a synthetic ID.
- Permission checks use the conversation's persisted workspace binding (`null` for scratch context), not the synthetic scratch ID.
- Scratch workspace tool usage does not mutate `toolsUsed`, project last-used timestamps, or project bindings.
- Shell is exposed only when the captured Android runtime reports `ready`, `engine=proot`, and `sandboxed=true`.
- Each Shell call waits for runtime initialization and re-reads runtime status immediately before execution.
- Every Shell command in the private conversation workspace requests a fresh manual approval, even in Full Access mode. The approval happens immediately before `runtime.run()`; no command starts while approval is pending.
- Skill execution is exposed only when a real workspace context and ready sandboxed PRoot are present. Each Skill run continues to require fresh manual approval even in Full Access mode.

### 3. Reliable model-facing environment facts

`environment_status` now reports distinct facts for RootFS metadata, PRoot runtime registration/readiness, a real command session inside Ubuntu, and chat workspace availability. A successful guest probe must emit its marker and exit with code 0 before `ubuntuReachable`, `shellAvailable`, or `skillExecutionAvailable` can become true.

The result explicitly tells the model:
- Trust the structured `assistantSummary`, `verifiedFacts`, `conversationWorkspace`, `prootHostRuntime`, `prootSession`, and package inventory.
- Do not infer the Android handset model from guest `MACHINE`, `KERNEL`, architecture, screenshots, or terminal output.
- Do not claim packages are absent when the actual count is unknown.
- Do not install or search for an APT package named `proot` as a check for Android's host PRoot runtime.
- Use Shell for live follow-up commands when the tool is available; do not claim a command ran if Shell is absent.

### 4. Regression coverage

Added/extended focused cases for:
- A ready conversation PRoot context exposing Shell and Skill execution.
- Synthetic conversation IDs not leaking into persisted project permission bindings.
- Shell calls routed to PRoot mounts only after fresh manual approval in Full Access mode.
- Non-PRoot runtimes never being reported as reachable Ubuntu.
- Successful environment diagnostics reporting the live Ubuntu session, package inventory, shell availability and Skill availability.
- An unready PRoot context not advertising Shell in the model prompt.

The focused Phase 13E runner includes the diagnostic test file and the dedicated ToolHandler gating test. Historical 13A–13D runners remain excluded from the active workflow, as previously agreed.

## Validation performed in this workspace

Passed:
- `bash .github/scripts/test_phase13e_ci.sh`
- `bash .github/scripts/release_hardening_audit.sh`
- `bash .github/scripts/audit_android_only.sh`
- `python3 .github/scripts/check_l10n_parity.py` — 4,791 messages; 4,670 Arabic translations (97.47%); 121 English fallbacks.
- Shell syntax checks for the Phase 13E scripts and the Android/release audit scripts.

Not run here:
- `flutter test` / `dart analyze` — Flutter and Dart SDKs are not installed in this packaging environment.
- Android ARM64 APK build and on-device PRoot execution/approval test.

## Acceptance procedure on the Android device

1. Install the APK from a fresh Phase 13E CI run.
2. Open a normal chat that is not bound to a project and ask the assistant to report its Ubuntu environment using `environment_status`.
3. Ask it to run a harmless command such as `printf KELIVO_CHAT_PROOT_OK` inside Ubuntu. A manual approval must appear even if Full Access is selected. Before approval, no process may start; after approval, the tool result must contain the marker.
4. Ask it to report `cat /etc/os-release`, `python3 --version`, `command -v apt`, and a read-only installed-package count from the guest.
5. Run an already-installed compatible Skill from that chat. It must receive its own fresh approval and use the conversation's isolated workspace paths.
6. Repeat in a chat with an explicitly selected project and confirm the project workspace remains selected and unchanged.

## Known limits

- PRoot is a userspace compatibility layer, not a kernel security boundary. A Skill or approved Shell command can modify the shared Ubuntu RootFS; the manual approval gate reduces accidental execution but does not create OS-level isolation.
- The private scratch workspace has no external SAF folders mounted. User files must be imported through the supported workspace/storage flow.
- This report records source-side preparation and static checks only. The phase is not accepted until focused CI, Android ARM64 Release compilation, and the on-device procedure above pass.
