# PHASE 1 — Implementation Report

**Implementation state:** Source changes prepared.

**Validation state:** Static source review completed. Flutter/Dart commands were not executable in the preparation container because Flutter and Dart SDKs are not installed there. Do not consider automated tests or APK build passed until CI reports success.

## Implemented

1. Added a generic extension record with schema version, ID, kind, name, source provenance, lifecycle status, version/digest, compatibility, permissions, entry point, timestamps, error code and metadata.
2. Added defensive validation for IDs/kinds, source URIs, credential-like source keys, safe relative paths, permission identifiers, JSON-only metadata, nested depth, field/item count and serialized metadata size.
3. Added a generic extension registry repository over the existing extension entity store. This avoids a database schema migration.
4. Added a lifecycle transition graph and watch/list/get/upsert/remove operations.
5. Added skill-to-registry synchronization while leaving the existing SkillRecord store as the source of truth for this phase.
6. Registered the new repository through the existing Provider container.
7. Removed default Skills asset seeding for `skill-creator` and `visualize`.
8. Moved those native capabilities into hidden Core guidance. Core guidance is injected independently of the user's installed Skills list.
9. Kept the active-install registry and SkillsService consistent; cross-reinstall preservation is not required for this development project.
10. Updated generated interactive-UI guidance path and relevant tests.

## Tests added or updated

- Extension record JSON round-trip and kind-ID coexistence.
- Rejection of embedded credentials and unsafe relative paths.
- Portable `update_available` status serialization.
- Extension registry kind isolation and lifecycle transition rules.
- Registry watch stream.
- Skill registry synchronization.
- Fresh installation with no seeded Skills.
- Core guidance present but not registered as a Skill.
- No data-preservation migration was added; the user resets local data between development installs.
- Interactive UI guidance files generated under hidden Core guidance rather than a Skill.
- Skill prompt includes native Core capabilities when no Skills are installed.

## Validation performed in preparation environment

- Reviewed changed source paths and provider wiring.
- Confirmed no references remain to the removed `assets/skills` bundle seeding APIs (`bundledAssets`, `_bundledSkillFiles`, `_seedBundledSkill`).
- Confirmed the existing database entity table is reused and the database schema version is unchanged by this phase.
- Confirmed new-install Skills behavior is covered by tests.
- Confirmed the extension registry is not coupled to a fixed video engine, provider, package or Skill catalog.
- Parsed `pubspec.yaml` and both Android/PR GitHub Actions workflows as YAML.
- Checked every relative Dart import in changed Dart files; no missing relative targets were found.
- Confirmed the old `assets/skills` directory is absent and no production engine/library is added as a fixed dependency.

## Not yet verified

- `dart format --output=none --set-exit-if-changed`.
- `dart analyze --fatal-infos lib test integration_test`.
- `flutter test`.
- Android ARM64 Release APK build.
- Runtime regression tests on the user's Android device.

These checks must run in GitHub Actions after uploading this phase archive. Any CI failure must be fixed before Phase 1 is marked complete.

## Known design decisions

- The existing Skill database record remains authoritative until the later general extension installer/update lifecycle is implemented.
- Registry metadata is an additive record type in the existing generic entity table.
- Native Core guidance is stored beneath a hidden directory inside the existing Skills workspace so current `read_file` routing can access it without adding another workspace mount.
- No Remotion, Manim, Motion Canvas, FFmpeg, model provider, or video skill is preinstalled by this phase.

## Next

Run the PR check workflow and Android ARM64 build. After both pass, mark Phase 1 accepted and begin Phase 2 (conversational extension commands). Do not start installing engines or dependencies before the Phase 2/3 design is implemented.
