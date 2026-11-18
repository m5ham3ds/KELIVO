# Phase 13E — Skill bundles, companion resources and chat file attachments

**Status:** Source correction prepared; CI and on-device acceptance pending.

## Why this correction was needed

The user confirmed that Ubuntu/PRoot was installed and the Phase 13E APK built, but Skill imports failed with `FormatException: SKILL.md not found` even when the app successfully downloaded a GitHub ZIP. The uploaded distribution archive was not a single Skill repository: it contained six ZIP archives under `Skills/`, plus package-level instructions and `Prompts.txt`. Direct GitHub `.skill` links were also interpreted as directory URLs. Separately, the chat attachment picker had a narrow extension filter that excluded ZIP and many other file types.

## Source changes

- Added nested Skill-bundle extraction. The outer ZIP is inspected, each nested ZIP is treated as an independent Skill/repository source, and the user can select all or a subset of compatible Skills before installation.
- Every selected Skill is installed into its own private managed directory. Its complete directory tree is preserved: `SKILL.md`, `scripts/`, `references/`, `assets/`, `examples/`, JSON data, images, fonts and other regular files. Binary files are copied as bytes, not decoded as text.
- Package-level documents such as installation notes and `Prompts.txt` are stored as shared package resources in the private import metadata area, separately from each Skill folder. Their manifest binding is informational/read-only; they are not automatically mounted into a Skill runtime.
- Added direct GitHub `blob`/`raw` handling for repository-relative `.skill` and `.zip` files. The selected file is extracted from a pinned repository snapshot, then passed through the same local importer. A direct `.skill` containing only Markdown cannot supply companion files that are not present in that file; users should import the complete Skill folder or ZIP when companions are required.
- The chat composer now offers `FileType.any`, with `withData: false`, and explicit MIME mappings for common archive and document formats. Unknown binary data remains `application/octet-stream`; ZIP/APK/binary files are not mislabeled as inline-readable text. Attachments can be copied into the conversation workspace for file tools when a verified conversation PRoot workspace is available. Otherwise the assistant receives safe metadata rather than fabricated file contents.
- Added a conservative completeness warning for explicit local file references in inline code or Markdown link targets. Warnings are retained in the import manifest, shown in the import report, and surfaced to the assistant after conversational installation. This check is heuristic and does not attempt to infer every runtime-generated output path.
- Import remains non-executing: no script is run and no dependency is installed during archive inspection or Skill installation. Existing ZIP traversal, symlink, entry-count and expanded-size limits remain in force.

## Supplied bundle inspection

The uploaded `Viral-Motion-Reel-Playbook_Skills.zip` contains six nested Skills:

1. `animation-director`
2. `ig-profile`
3. `ig-viral`
4. `arabian-motion-video-director`
5. `ig-reel`
6. `character-visual-director`

The `character-visual-director` archive's full `examples/` tree, PNG character sheet and WOFF2 font files are retained as binary files. `ig-profile` retains `rubric.json`; `ig-reel` retains `beats.py`, `hooks.json` and `hookscore.py`; the remaining resources are retained as supplied.

The supplied `arabian-motion-video-director` nested ZIP contains **only `SKILL.md`**. Its instructions explicitly refer to files that are absent from the archive, including:

- `scripts/preflight.sh`
- `scripts/preview.mjs`
- `scripts/create_env.sh`
- `scripts/normalize_env.py`
- `references/arabic-rtl-production.md`

The importer cannot reconstruct those missing files. It therefore allows the otherwise valid Skill to be imported with a warning, rather than silently treating it as complete. `ig-viral` also refers to `hooks.json`, which is not included in that Skill's own ZIP; the presence of a different `hooks.json` inside `ig-reel` does not cause it to be copied across Skills.

## Focused regression coverage

The active Phase 13E runner now includes dedicated tests for:

- extraction of nested Skill ZIP bundles and preservation of text/binary companion files;
- atomic installation of multiple Skills, shared package documents and import-manifest completeness warnings;
- direct GitHub `.skill` and `.zip` file URL parsing and safe exact-file extraction;
- detection of missing local companion references without warning for project-generated files or references already present;
- file picker support for arbitrary extensions while avoiding loading complete binary files into RAM.

Historical Phase 13A–13D test runners remain excluded from the active workflow, per the user's prior confirmation that those phases had already passed.

## Acceptance still required

Local checks cover shell syntax, Phase 13E CI orchestration, supplied archive structure and ZIP integrity. This environment does not contain Flutter or Dart, so Flutter tests, Dart analysis and Android ARM64 Release compilation have **not** been executed here. GitHub Actions must pass the new focused suites and produce the APK. On-device verification must then confirm that importing the supplied multi-Skill ZIP shows six candidates, preserves all supplied companion files, reports the missing resources above, and that a chat message with a ZIP/document attachment can be accessed by conversation file tools through PRoot.
