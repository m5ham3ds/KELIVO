# Product — Kelivo Android Edition

Kelivo is an Android-first, conversation-centric LLM workspace for model providers, chat, files, tools, search, voice, assistants, workspaces and optional Agent Skills.

The current repository and supported release target are Android only. Linux command-line environments run inside the Android PRoot workspace; they are not Linux desktop builds. iOS, Windows, macOS, desktop Linux and Web are not currently supported targets in this source snapshot.

## Product principles
- Keep conversation and the user's current task visually primary.
- Explain what safety controls enforce and what they cannot enforce.
- Keep Skills, MCP servers, video engines and extensions optional.
- Never treat imported extension metadata as permission to execute code or connect to a service.
- Prefer recoverable, user-owned data flows with explicit outcomes.
- Preserve Android accessibility, localization, scalable text, keyboard/touch support and light/dark themes.

## Current capabilities and boundaries
- Skill-local Python/Bash/Node execution uses the approved Android PRoot path. PRoot is not a kernel sandbox; the active RootFS is shared and writable, and guest network access is not fully restricted.
- Skill-owned MCP ownership, approval, `tools/list`/`tools/call`, lifecycle invalidation and secret redaction have backend/lifecycle acceptance evidence in CI #199, with real STDIO child-process and hostile-server acceptance in Phase 14D / CI #204.
- CI #208 revalidated the Skill-owned MCP/STDIO test group. This does not prove the complete visible approval UX on a real device or Force Stop recovery.
- Native Kelivo tools execute through the existing ToolCallHandler and permission gateway. The universal Tool Registry/Toolsets integration is being completed in Phase 14E; descriptors do not by themselves grant execution.
- Generic HTTP/API connector adapters and generic Skill workflow execution are not yet accepted as universal capabilities. A manifest or descriptor alone never authorizes network access or execution.
- Without private signing configuration, a successful CI APK is debug-signed and is not a Play Store publishing credential.

## Current development state
The active phase is Phase 14E. Phase 14A–14D are accepted; Phase 14E.1 targeted tests passed in CI #206 and Phase 14E.2 turn-scoped integration tests passed in CI #208. Phase 14E remains open until native tool parity, real Toolset selection, direct/deferred/hidden exposure and the remaining budget/approval/cancellation gates pass.
