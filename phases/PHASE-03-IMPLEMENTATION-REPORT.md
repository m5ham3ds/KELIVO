# PHASE 3 — Dynamic Skills Compatibility & Import

**Status:** Implementation prepared; awaiting focused GitHub Actions analysis/tests and Android ARM64 Release build.

## Scope followed

This implementation covers only Phase 3 of `MASTER-DEVELOPMENT-PLAN-AR.md`. It does not introduce multi-Skill workflow composition (Phase 4), package-manager installation (Phase 5), runtime profiles (Phase 6), or video engines/providers from later phases.

## Implemented capabilities

### 1. Agent Skills `SKILL.md` conformance

- Replaced the simplified metadata parser with YAML frontmatter parsing.
- Validates required `name` and `description` and supported optional fields `license`, `compatibility`, `metadata`, and `allowed-tools`.
- Validates slug syntax, directory-name matching, and specification length/type limits.
- Counts description and compatibility limits in Unicode code points.
- Preserves unknown frontmatter extension fields and surfaces compatibility warnings instead of silently discarding them.
- Keeps the original Markdown instruction body intact.

### 2. Repository and archive import

- Supports GitHub repository, tree/subfolder, blob/raw file links, explicit branch/tag/commit refs, and refs containing slashes through `?ref=`.
- Discovers multiple Skills in one repository ZIP and lets the caller select one or more paths before installation.
- Keeps files attached to their nearest/deepest Skill root; nested Skills do not inherit files belonging to a parent Skill.
- Supports local Skill folders, Markdown files and single-Skill ZIP packages.
- Preserves `scripts/`, `references/`, `assets/`, and other additional files.
- Enforces archive traversal, symbolic-link, file-count, input-size and aggregate expanded-size safeguards.

### 3. Inspection and compatibility report

- GitHub, local and `skills.sh` sources can be inspected before installation.
- Previews include metadata, description/body preview, file counts, script counts, and compatibility findings.
- Platform-specific extension folders/configurations are preserved and reported as not interpreted by the generic Agent Skills adapter.
- Scripts and package-manager commands are never executed during discovery, preview, extraction or installation.

### 4. `skills.sh` adapter boundary

- Added a generic `SkillsCatalogAdapter` contract and a `SkillsShAdapter` implementation.
- Supports skills.sh search and detail resolution for GitHub-backed entries.
- Validates catalog IDs and returned file paths, enforces response/file limits, and validates the resolved `SKILL.md` before installation.
- Other catalog source types, including `well-known` entries, are not advertised as installable until a dedicated source adapter exists. This is intentional rather than a silent fallback.

### 5. Private GitHub repositories

- Added a credential-store abstraction with Android secure storage for the production token and an in-memory test implementation.
- Validates a supplied token against GitHub `/user` before persisting it.
- Uses the credential only for GitHub API requests; it is not copied into source URLs, Skill records, operation history or logs.
- Does not forward the token to archive redirect hosts, and rejects non-HTTPS, untrusted-host and non-standard-port redirects.

### 6. Conversational and UI integration

- Added GitHub/catalog scopes and skill-path selection to conversational extension search/inspect/install flows.
- Multi-Skill repositories can be inspected and selected before the service commits any installation.
- Added `skills.sh` discovery/preview and private GitHub access controls to the Skill import UI.
- Updated the Skill prompt to use progressive disclosure: read only the relevant Skill instructions/references when needed rather than injecting entire directories into every request.

## Focused regression coverage added

The Phase 3 Android CI manifest now targets the extension lifecycle and the compatibility/import contracts, including:

- YAML frontmatter fields, malformed metadata and Unicode length limits.
- GitHub URL/ref parsing and path validation.
- Multi-Skill archive extraction, nested Skill ownership and aggregate extraction limits.
- Compatibility reporting for platform-specific extensions.
- `skills.sh` search/detail adapter behavior.
- Private credential validation and non-forwarding of tokens on redirects.
- GitHub multi-Skill selection and local/catalog preview without executing scripts.
- Existing Phase 2 registry, conversational command and UI regressions.

The workflow analyzes production `lib` sources plus the explicit Phase 3 whitelist and runs only that whitelist plus the two named Android chat UI regressions. It does not execute the repository-wide test suite or test suites for iOS, macOS, Windows, Linux or Web.

## CI/reporting improvements included

- Phase 3 has its own focused analysis/test scripts and manifest.
- APK packaging was moved into `.github/scripts/package_android_apk.sh` to avoid nested shell-quote parsing errors.
- The package script writes APK name/path/size/SHA-256 metadata for the build report.
- The report generator now distinguishes a successful APK upload from absent metadata and does not claim that an APK was not produced when GitHub's job-step result says otherwise.

## Dependencies

- `yaml` is used for standards-compliant frontmatter parsing.
- `flutter_secure_storage` supplies the Android secure credential-store implementation.
- The preparation environment does not include Flutter/Dart SDK, so the lockfile was not regenerated here. GitHub Actions runs `flutter pub get` before analysis/build and must confirm dependency resolution and lockfile consistency on the runner.

## Known limitations

1. `skills.sh` entries backed by GitHub are supported. Non-GitHub `well-known` source types are detected as unsupported until a dedicated adapter is implemented.
2. Platform-specific plugin/manifests are preserved and flagged; this is not a promise that Claude-, Cursor-, Codex- or other host-specific plugin runtimes are executable in Kelivo.
3. `allowed-tools` is preserved as a compatibility hint only. It does not grant Kelivo execution permissions.
4. Scripts are preserved and counted, but are not run. No package installation or external dependency setup is attempted in Phase 3.
5. Private repository access uses a user-supplied GitHub token; the user must grant only the repository read permissions needed for the selected private repository.
6. Full Android tests and an APK build for this Phase 3 source snapshot remain pending the next GitHub Actions run.

## Acceptance criteria for this phase

- A standard Agent Skill with valid YAML frontmatter can be imported without rewriting its `SKILL.md`.
- One or multiple skills can be selected from a GitHub repository/subfolder, with nested files assigned to the correct Skill.
- Local and skills.sh GitHub-backed candidates can be inspected before installation.
- Private GitHub imports authenticate without leaking credentials to archive hosts or records.
- Additional files are preserved and no source scripts execute during import/inspection.
- Unsupported platform-specific features are explicitly reported.
- Android Phase 3 analysis, focused tests and ARM64 Release build pass in GitHub Actions.
