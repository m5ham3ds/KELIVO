# Phase 12 — Skill Packs, Conversation Shortcuts & Source Refresh

## Purpose

The post-install device check exposed a mismatch between the user-facing concept and the storage model: eleven related YouTube Skills were installed as eleven independent rows, all appeared enabled, and the user had no compact way to select the toolkit for a single conversation. The same check also exposed a legacy update-source problem: an installed Skill could have only a broad `github`/`skillsSh` source marker without a replayable origin URL, so an Update command started but could not resolve a download.

This implementation adds a user-facing Skill Pack layer while keeping every underlying Agent Skill as its own standards-compliant directory with its own `SKILL.md` and supporting files.

> **Supersession note — Phase 13E (2026-11-13):** the original implementation below described exclusive membership and Pack-owned activation. That behavior caused original Skills to disappear from standalone lists and their enabled state to be overwritten by Pack state. It is superseded by [the Phase 13E independent-member correction](PHASE-13E-SKILL-PACK-INDEPENDENT-MEMBERS-AR.md): a Pack is now a non-exclusive reference grouping; every original Skill remains visible, individually enabled/disabled and selectable; Pack activation is stored separately; editing/deleting a Pack never changes its members. User-created Packs are organizational shortcuts and do not own member updates; only repository-detected groups may refresh together from one upstream source, while manual-Pack members update independently. The historical implementation details below are retained to explain the previous behavior, not as the current contract.

## Implemented behavior

### 1. Automatic repository packs

- Skills imported from the same GitHub repository are grouped into one automatically detected pack. Skills imported from the same `skills.sh` owner/repository are grouped the same way.
- Each Skill remains independently stored and can still be inspected, composed, updated, rolled back and removed.
- The automatic pack uses a repository-derived name and a unique slash shortcut. Existing user ordering and shortcut values are preserved on rescan.
- Newly detected packs start disabled by default. This prevents the entire toolkit from being silently injected into every unrelated chat.
- A Skill belongs to at most one pack. Moving it into a manually edited pack removes it from its previous pack instead of creating duplicate activation switches.

### 2. Manual packs and ordering

- The Skills page now exposes **Update all**, **Create pack**, and the existing import action in its AppBar; the embedded pane header exposes the same actions.
- Users can create or edit a pack, choose multiple installed Skills, give the pack a name/description and a unique lowercase slash shortcut, and drag to reorder members.
- Packs themselves can be moved up/down in the Skills library.
- Deleting a pack does not delete its Skills. Deleting a Skill removes only that member and reconciles the containing pack.
- Pack activation is the source of truth. Legacy per-Skill enabled flags are mirrored to the pack state during load, edit, activation, deletion and refresh. The legacy `setEnabled(skillId, ...)` entry point delegates to its containing pack.

### 3. Per-conversation selection and slash shortcuts

- Conversation Skills settings show a pack as one selectable row rather than displaying its members as unrelated Skills.
- Selecting a pack adds all member Skill IDs to the conversation binding; deselecting it removes all of them.
- Typing `/` at the start of the composer shows matching pack shortcuts. Multiple packs can be selected in one message, for example `/youtube /editing`.
- A command-only message such as `/youtube` activates the pack without sending a prompt. For an existing conversation, the binding is saved immediately. For a new conversation, the selection is retained as pending composer state and applied when the first real message creates the conversation.
- The slash tokens are removed before the prompt is sent to the model. The selected IDs are stored in `skills.ids`, so later turns use the same conversation binding.
- Any legacy assistant/conversation selection that references one member of a pack resolves to the whole pack, preserving expected toolkit behavior.
- The existing `skill_compose` progressive-disclosure planner remains in place; pack selection does not concatenate all instructions into one oversized prompt. The planner still decides which member Skills are relevant to the task.

### 4. Pack refresh and repair of legacy sources

- The Skills library includes an **Update all** action and repository packs expose a single **Update pack** action when all members have supported remote provenance.
- Updating one member from a pack through `extension_update` resolves to its containing pack when no alternate source is specified.
- A GitHub repository pack groups members by repository/ref and downloads each distinct repository/ref archive once, instead of downloading the same repository separately for every member. Each installed Skill retains its own rollback snapshot.
- `skills.sh` packs update their members from their stored catalog IDs.
- Existing remote Skills whose legacy record says only `github` or `skillsSh` but lacks a valid origin expose **Connect update source** in the library, detail actions and pack editor. The user can provide a validated GitHub Skill/repository URL or a `skills.sh` Skill URL.
- Connecting a source only updates origin metadata; it does not overwrite installed files. Replacing an old source also clears stale ref/subpath/revision fields, so a newly selected repository root cannot inherit an obsolete folder path.
- Unsupported local/pasted Skills do not show a misleading refresh action. They remain editable/exportable.
- The previous vague `invalid_input` update failure is replaced with an actionable source-missing error that directs the user to connect the original source.

### 5. Localization and UI

- Added localized strings for connecting update sources and the explicit **Update all** action in English, Arabic, Simplified Chinese, Traditional Chinese and the Chinese fallback template.
- Skill Pack editor uses a dialog on desktop layouts and a bottom sheet on mobile layouts.
- Update-source controls have unique keys per Skill so multiple legacy Skills can be repaired in the same list without duplicate widget keys.

## Focused regression coverage added/updated

- A GitHub import test verifies that multiple Skills from one repository become one ordered pack and update with one repository archive download.
- A source-repair test verifies a legacy remote Skill can attach a GitHub source, become updateable, and replace/clear old path metadata when a new repository root is connected.
- Pack activation tests verify a disabled pack is not injected by default, selecting one of its members selects the whole pack for a conversation, and legacy per-Skill toggles delegate to the pack switch.
- Skills pane tests verify AppBar controls, pack creation and the legacy update-source connection action.
- Conversation Skills panel tests verify a pack is presented and selected as one unit, writing all member IDs into the conversation binding.
- Existing slash-command composer implementation supports suggestions, multiple leading pack shortcuts, command-only activation and first-message pending state. It remains part of the targeted manual/device verification gate.

## Static checks completed in the preparation environment

- Arabic ARB parity: **4,733 messages**, **4,614 Arabic translations (97.49%)**, **119 English fallbacks**; key and placeholder parity passed.
- All 34 YAML/YML documents parsed successfully.
- All ARB files parsed as JSON.
- `bash -n` passed for all 30 `.github/scripts/*.sh` scripts.
- Android-only audit passed, including ARM64-only ABI and PRoot archive/checksum validation.
- Release hardening audit passed.

## Verification limits and acceptance gates

The preparation environment does not contain Flutter or Dart executables. Therefore the following have **not** been run here: `dart format`, `dart analyze`, focused Flutter widget/unit tests, `flutter gen-l10n`, Pub resolution and Android ARM64 Release compilation. The active Android workflow already runs `flutter gen-l10n`; the newly added ARB keys must be generated before compilation.

Do not mark this feature or Phase 12 accepted from static checks alone. The next GitHub Actions run must pass dependency resolution and ARM64 Release packaging. Then validate on the Android phone:

1. Confirm the eleven YouTube Skills appear as one repository pack, with all original files and per-Skill detail preserved.
2. Confirm the pack starts disabled globally and can be enabled/disabled as one unit.
3. In a new chat, type `/`, choose `/youtube`, send a prompt and verify the first turn sees all relevant Skills from the selected pack only.
4. Select two packs in one chat and verify unrelated packs remain unavailable.
5. Update the repository pack once and verify all members refresh while rollback snapshots remain available.
6. Repair a legacy source, update one member and verify the pack refresh operation reports useful progress/errors rather than `invalid_input`.
7. Restart the app and verify packs, shortcuts, ordering and conversation bindings persist.

The previous user-confirmed Android ARM64 Release build (KELIVO 1.3.4+84) remains the baseline. This Skill Pack source change has not yet been built or device-verified.


## Post-report device validation update — 2026-11-10

The verification limits above describe the state when this implementation report was authored. In a later device-validation turn, the user confirmed that the updated project built successfully and manually verified Skill Pack installation, update, grouping/selection and creation of a pack/variable containing selected Skills. This confirms those specific user-facing flows on the user's device; it does **not** confirm execution of Skill-local scripts, CLI binaries, MCP servers or API tools. Those execution gaps are the subject of Phase 13 and remain unaccepted until independently implemented and tested.
