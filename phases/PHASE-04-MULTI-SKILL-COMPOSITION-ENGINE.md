# PHASE 4 — Multi-Skill Composition Engine

## Status

Implementation is prepared in the source tree. Android CI, Dart analysis, the focused regression suite, and an ARM64 Release build are still required before this phase can be accepted.

Phase 3 implementation is present but its formal GitHub Actions acceptance is still pending. The user explicitly requested that development continue to the next planned phase without waiting for Phase 3 acceptance. Phase 4 therefore proceeds while preserving that dependency status; it does not silently mark Phase 3 accepted.

## Goal

Allow the conversation agent to compose multiple installed Agent Skills for one task, validate requirements and conflicts before exposing their instructions, and return a dependency-aware plan with explicit artifact contracts and a bounded instruction budget.

## Implemented scope

### Selection modes

- `automatic`: deterministic lexical matching over task words, Skill name, description, and `metadata.kelivo.tags`.
- `explicit`: use the ids explicitly requested by the user/agent.
- `assistant_default`: use the assistant's Skill preference. An unset assistant preference means all enabled Skills in the current assistant scope.
- `project_default`: use the active workspace Project Default Skills. An unset workspace setting inherits the assistant setting, or all enabled Skills where no assistant preference is configured.
- `conversation_override`: use the Skill ids bound to the current conversation only.
- Explicit exclusions apply to root selections and transitive requirements.

Automatic discovery is a lightweight deterministic lexical matcher, not embeddings or a remote semantic search. It selects up to six initial matches; dependency resolution can add required Skills, with a hard maximum of twelve selected Skills.

### Skill contracts

Kelivo-specific composition metadata stays inside the standard Agent Skills `metadata` string map. The imported `SKILL.md` is not rewritten.

Supported keys are comma-separated strings:

| Key | Meaning |
|---|---|
| `kelivo.tags` | Extra terms used by automatic discovery |
| `kelivo.requires` | Installed Skill ids that must be selected first |
| `kelivo.conflicts` | Skill ids that cannot be composed together |
| `kelivo.inputs` | Artifact ids consumed by the Skill |
| `kelivo.outputs` | Artifact ids produced by the Skill |
| `kelivo.writes` | Relative workspace paths written by the Skill |
| `kelivo.tools` | Tool names the Skill expects to use |
| `kelivo.permissions` | Permission declarations surfaced for review; never granted by the planner |
| `kelivo.platforms` | Supported targets (`android`, `ios`, `linux`, `macos`, `windows`, `web`, `all`) |
| `kelivo.engine` | Optional engine identifier used for compatibility warnings |

Example:

```yaml
---
name: scene-builder
description: Build storyboard scenes from a script.
metadata:
  kelivo.tags: storyboard, scenes, animation
  kelivo.requires: story-planner
  kelivo.inputs: storyboard.json
  kelivo.outputs: scene-plan.json
  kelivo.writes: project/scenes
  kelivo.platforms: android, all
---
```

`kelivo.requires` references the installed Kelivo Skill ids. Internal Skill ids may be suffixed when duplicate Skill names are imported; source frontmatter name/folder conformance is validated during import and is not re-checked against a potentially suffixed internal record id at composition time.

### Planning and safety

- Build dependency edges from required Skills and artifact producers/consumers.
- Topologically group independent Skills into parallel stages, or sequential stages when parallel execution is disabled.
- Block missing or excluded requirements, declared conflicts, cycles, duplicate artifact producers, overlapping write paths (including parent/child paths), tool-name collisions, invalid contract metadata, incompatible platforms, invalid/mismatched pinned SHA-256 digests, and exceeded context budgets.
- Warn on compatibility extensions that Kelivo does not interpret, engine mismatches without an ordering dependency, and declared permissions that need review.
- Do not inject any selected Skill instructions when the plan has an error.
- Expose selected Skills, selection reasons, scores, DAG stages, artifact input/output contracts, permission declarations, warnings, pinned digests and the estimated instruction budget in a structured result.
- Context estimation is deliberately labelled as a heuristic (`ceil(Unicode code points / 2)`), not an exact provider tokenizer.
- `skill_compose` is a read-only planning tool. It does not execute Skill scripts, run shell commands, install dependencies, grant permissions, or perform actual parallel execution itself.
- The agent may use approved existing Kelivo tools after a ready plan and should pass artifact paths/references between stages. A dedicated runtime executor, durable artifact store, automatic file transfer, and resumable workflow execution are outside this implementation slice and must be added with the later runtime/workflow phases before claiming end-to-end execution acceptance.

### Workspace Project Defaults

The `Workspace` JSON payload now supports nullable `skillIds`. `null` means inherit assistant defaults (or all enabled Skills if the assistant has no explicit preference); a list, including an empty list, means an explicit workspace configuration. The field is backward-compatible with existing workspace JSON and requires no SQLite schema migration because workspaces are stored as JSON extension entities.

The conversation Skills panel exposes Project Default Skills for the workspace bound to the current conversation. It allows inheritance or an explicit workspace selection. This setting is independent of the assistant's Skill list, but only enabled installed Skills can be composed.

### Conversation tool and UI

`skill_compose` is registered as a reserved local built-in tool and is visible in the conversation tool catalog. It supports task, mode, explicit ids, exclusions, context budget, parallel-stage preference, and optional pinned digests. The workspace tool timeline renders the plan status, selected Skills and reasons, execution stages, approximate context budget, and issues.

## Key source files

- `lib/core/services/skills/skill_composition_planner.dart`
- `lib/core/services/skills/skill_composition_service.dart`
- `lib/core/services/extensions/skill_composition_tools.dart`
- `lib/core/models/workspace.dart`
- `lib/features/home/services/tool_handler_service.dart`
- `lib/features/workspace/widgets/skills/conversation_skills_sheet.dart`
- `lib/features/chat/widgets/workspace_tool_ui.dart`

## Deferred items / acceptance gaps

1. No Workflow Profile persistence/editor yet; this was optional in the plan.
2. No semantic embedding-based Skill discovery; matching is deterministic lexical matching.
3. No version-range resolver for inter-Skill dependencies.
4. No runtime executor or actual filesystem artifact transfer between stages. The current feature produces and displays a validated plan and contracts only.
5. No actual Skill script execution or package installation; those require the later package/runtime/security phases.

## Acceptance criteria

- Request two or more Skills and produce a deterministic ordered composition plan.
- Resolve transitive `requires` dependencies and explain why each Skill was selected.
- Detect missing/excluded requirements, conflicts, cycles, duplicate/overlapping outputs, tool collisions, incompatible platforms, invalid digests and context-budget overflow before injecting instructions.
- Display the selected Skills and dependency stages in the chat timeline.
- Preserve assistant defaults, conversation overrides and independent workspace Project Defaults.
- Keep Android-only CI limited to the explicit Phase 4 test manifest and three named chat UI regressions.
- Pass Dart analysis, all focused Phase 4 tests, and an Android ARM64 Release build in GitHub Actions.
- End-to-end artifact transfer/parallel execution remains a separately tracked acceptance gap until a runtime executor exists; do not mark the phase fully accepted before that work is implemented and tested.
