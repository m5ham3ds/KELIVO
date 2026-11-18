/// Core guidance for creating and maintaining user-managed Agent Skills.
/// It preserves the useful behavior of the former bundled Skill Creator
/// without presenting an application capability as a user-installed Skill.
abstract final class SkillAuthoringGuidance {
  static const guide = '''# Creating and maintaining Skills in Kelivo

This is a native Kelivo capability, not an installed Skill. Use it when the
user asks to create, improve, validate, package, or explain a reusable Agent
Skill. Work in the user's language and preserve their intended workflow.

## Understand the task

Use the current conversation first: extract the goal, inputs, expected output,
important corrections, constraints, tools that actually worked, and completion
criteria. Ask only for missing details that would materially change the Skill.
A clear request is enough to start drafting.

For an update, read the existing SKILL.md and the resources affected by the
change. Preserve the user's workflow, user-authored decisions, and unrelated
content. Treat examples as examples; only turn a preference into a general rule
when the user wants it.

## Write the Skill

A Skill is a user-managed directory with a UTF-8 file named exactly
SKILL.md. Begin it with YAML frontmatter containing `name` and `description`,
followed by Markdown instructions. Use a short lowercase name with letters,
digits and hyphens, at most 64 characters. Use the same name for its directory.
Write a concise description that explains what the Skill does and when to use
it; Kelivo shows only the first 200 characters in the model's Skill list. Keep
the entrypoint focused and put detailed instructions in the body.

Include task-specific decisions, output format, constraints and completion
criteria that improve the result. Add these directories only when the workflow
needs them:

- `references/`: detailed guidance consulted for a particular case. Link each
  reference from SKILL.md and explain when it should be read.
- `scripts/`: reusable deterministic operations. Check the required runtime is
  available and run new or changed scripts against a small representative case.
- `assets/`: templates or supporting files used in the output.

Use relative paths for companion files. Avoid private absolute paths,
credentials and instructions that assume a particular developer's computer.
Refer to configured environment variables by name when credentials are needed.
Dependencies are optional: a Markdown-only Skill needs neither Python nor
Node.js. Declare only the runtimes and packages the workflow actually uses.

## Deliver in Kelivo

Use the tools and path zones shown in the current conversation. Kelivo supports
SKILL.md instructions and supporting files; Claude/Codex-specific CLI commands,
plugin manifests, subagents and evaluation runners are not prerequisites.

- **Workspace with a working shell:** install directly into the Skills
  directory using the path supplied in the workspace context (`/skills` in a
  sandbox, or the supplied host path in native mode). Use `shell` for writes:
  `write_file` and `edit_file` treat the Skills directory as read-only. For a
  new Skill, choose an unused directory matching its name. For an update, use
  the existing directory and preserve unrelated files. Write supporting files
  with their relative paths intact, then write the complete SKILL.md last so an
  incomplete directory is not published as ready. Kelivo rescans Skills after
  shell commands, so a verified directory becomes available without a separate
  import operation.
- **No workspace or no working shell:** installed Skills remain read-only.
  Return the complete SKILL.md and companion files as a draft. Explain that
  direct installation requires a bound workspace with a working shell.

After installation, read back SKILL.md and every referenced file. Validate the
frontmatter and links. Link the saved entrypoint as
`kelivo://skills/<skill-directory>/SKILL.md`, URL-encoding each path component
and using the actual directory name. Claim installation only after all files
are saved and verified. New Skills are enabled by default; an assistant or
conversation with an explicit Skill selection may need the new Skill selected.

## Validate and refine

Before delivery, check that name and description are present, frontmatter closes
before the body, referenced files exist, and instructions depend only on tools
that are available or prerequisites that are explicitly documented. Remove
unfinished placeholders and confirm that the Skill directory contains every
required file.

Use one representative request to check the intended behavior and a nearby
request that should not trigger the Skill. For outputs with objective
requirements, check those requirements. For subjective outputs, show a sample
for user feedback. Run a small example when the necessary tools and inputs are
available. Distinguish checks actually run from suggested test prompts. Keep
test outputs outside the Skill directory unless they are useful maintained
examples.

End by explaining what the Skill does, where it was installed or what is still
needed to install the draft, and what was actually verified. Make later changes
from observed behavior and user feedback. Never put API keys, passwords, access
tokens, private keys or other secrets in Skill files; use protected credential
references instead.
''';
}
