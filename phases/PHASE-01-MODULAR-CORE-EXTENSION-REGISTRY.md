# PHASE 1 — Modular Core and Extension Registry

**Status:** Implemented in source; pending GitHub Actions analysis, test and Android build acceptance.

## Goal

Create a small, persistent, typed registry for all optional extension types without shipping a fixed collection of Skills, video engines, libraries or model providers. Separate Kelivo's native core capabilities from user-installable Skills.

## Scope

### Included

- Versioned extension metadata model.
- Provenance, compatibility, digest, permissions and entry-point metadata.
- Typed extension kinds represented by validated identifiers: `skill`, `engine`, `tool`, `provider`, `workflow`, `asset`, and future kinds.
- Lifecycle states: `discovered`, `downloaded`, `validated`, `installed`, `enabled`, `disabled`, `incompatible`, `update_available`, `failed`.
- Generic persistent registry backed by the existing `extension_entity_rows` table; no new SQLite schema migration.
- A repository API for list/get/upsert/remove/watch and guarded lifecycle transitions.
- Synchronization of current Skill records to generic extension registry records.
- Provider registration for `ExtensionRegistryRepository`.
- Removal of automatic seeding of bundled `skill-creator` and `visualize` Skills.
- Migration of native skill-authoring and interactive-UI guidance into hidden Core guidance files that are not enumerated as installed Skills.
- Registry compatibility for the Skill records present in the current development database; preserving local test data across reinstallations is not a project requirement.

### Explicitly excluded

- Skill installation/update/remove commands from chat (Phase 2).
- General-purpose skill compatibility adapters (Phase 3).
- Multi-skill composition/planning (Phase 4).
- Package/dependency manager (Phase 6 in the master plan).
- Video engines, video providers, FFmpeg installation or video-specific defaults.
- UI pages for managing generic extensions.

## Registry contract

Each registry record includes:

- `schemaVersion`
- `id`, `kind`, `name`
- `source` (`type`, optional `uri`, `ref`, `subpath`, `revision`)
- `status`
- optional `version`, `digest`, `entryPoint`, `installedAt`, `lastErrorCode`
- `compatibility`, `permissions`, and safe non-secret `metadata`
- `updatedAt`

Credentials must be stored in a protected credential store in a later phase, never in this registry record. Source URIs containing userinfo or credential-like query/fragment keys are rejected. Relative paths reject traversal, absolute paths, control characters and Windows drive syntax. Compatibility and metadata payloads are bounded.

## Lifecycle transition contract

- `discovered` → `downloaded`, `failed`, `incompatible`
- `downloaded` → `validated`, `failed`, `incompatible`
- `validated` → `installed`, `failed`, `incompatible`
- `installed` → `enabled`, `disabled`, `update_available`, `failed`, `incompatible`
- `enabled` → `disabled`, `update_available`, `failed`, `incompatible`
- `disabled` → `enabled`, `update_available`, `failed`, `incompatible`
- `update_available` → `downloaded`, `disabled`, `failed`
- `incompatible` → `discovered`, `downloaded`, `failed`
- `failed` → `discovered`, `downloaded`, `validated`

Skill enablement remains synchronized with the existing SkillsService source of truth.

## Core guidance migration

The former bundled `skill-creator` and `visualize` Skills represented native Kelivo capabilities rather than user-selectable production extensions. New installs no longer seed either Skill. Their required guidance is now written under:

- `/skills/.kelivo-core/skill-authoring/GUIDE.md`
- `/skills/.kelivo-core/intelligent-ui/GUIDE.md`
- `/skills/.kelivo-core/intelligent-ui/references/`

The hidden `.kelivo-core` directory is excluded from Skill enumeration. No app-data preservation or migration layer is required for this development project. A fresh install may start with a clean local database and Skills directory; the registry remains consistent with whatever Skills are present in the active install.

## Files changed

- `lib/core/models/extension_record.dart` — validated versioned metadata and lifecycle values.
- `lib/core/services/extensions/extension_registry_repository.dart` — persistence, querying, lifecycle transition validation and Skill reconciliation.
- `lib/core/database/extension_entity_store.dart` — generic registry storage kind constant only; no schema migration.
- `lib/main.dart` — dependency injection for the registry repository.
- `lib/core/services/skills/skills_service.dart` — no bundled asset seeding; Core guidance bootstrap; registry reconciliation.
- `lib/core/services/skills/skills_prompt.dart` — Core capabilities injected independently of installed Skills; no special priority for legacy `visualize`.
- `lib/core/services/skills/core_guidance_service.dart` — writes hidden app-managed guidance safely.
- `lib/core/services/skills/skill_authoring_guidance.dart` — native Skill authoring guide.
- `lib/features/intelligent_ui/catalog/ui_guidance.dart` — UI guidance represented as native Core guidance.
- `lib/core/models/skill_record.dart` — documents legacy `bundled` source compatibility.
- `lib/features/home/services/message_builder_service.dart` — injects Core capabilities even when there are no installed Skills.
- `tool/genui_guidance.dart`, `tool/genui_eval.dart`, `pubspec.yaml`, and `assets/core_guidance/intelligent-ui/` — generated guidance paths.
- Tests under `test/core/models/`, `test/core/services/extensions/`, `test/core/services/skills/` and `test/features/intelligent_ui/`.

## Acceptance criteria

- A fresh install has no pre-installed Skills in the Skills directory or Skill database rows.
- Core app guidance remains available to the model without being exposed as a user-installed Skill.
- A clean development install starts without fixed Skills; whatever optional Skills are installed afterward remain manageable through the SkillsService.
- Skill import, enable/disable and delete operations synchronize registry metadata.
- Different extension kinds can use the same ID without collision.
- Invalid lifecycle transitions, path traversal and credential-like metadata are rejected.
- Existing chat, model providers, workspace tools and PRoot remain unaffected.
- `flutter analyze`, targeted tests, full `flutter test` and Android ARM64 release build pass in GitHub Actions.
