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

## Current boundaries
- Skill-local Python/Bash/Node execution uses an approved Android PRoot path; PRoot is not a kernel sandbox.
- Skill-declared MCP configuration is discovered and preserved, but the Skill-owned activation and tool-dispatch adapter is still in progress.
- HTTP/API connectors, generic workflows and native Kelivo tools are not executable merely because their descriptors were imported.
- Without private signing configuration, a successful CI APK is debug-signed and is not a Play Store publishing credential.
