/// Tool schema for explicit, per-run execution of a declared Skill entry point.
/// The server revalidates the composition, manifest, file digests and runtime
/// profile; model-supplied paths are never used as shell commands directly.
abstract final class SkillExecutionToolNames {
  static const String execute = 'skill_execute';
  static const Set<String> all = {execute};
}

abstract final class SkillExecutionToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    {
      'type': 'function',
      'function': {
        'name': SkillExecutionToolNames.execute,
        'description':
            'Execute exactly one declared Python, Bash, or Node.js entry point from an enabled installed Agent Skill, after a mandatory per-run manual user approval (including when Full Access is enabled). Requires an extension Runtime Profile owned by that Skill. Uses separate integrity-checked per-run source, input, output and temporary paths; the full Workspace, chat files, installed Skills tree and external mounts are not attached. Source/input binds are marked read-only and common write commands are guarded, but interpreters, shell redirection, absolute executables, direct syscalls and modification of shared guard files can bypass those guards. Custom Runtime Profile environment variables and Android host credentials are withheld. IMPORTANT: the active PRoot RootFS remains shared and writable, and device network access is unrestricted. PRoot is not a kernel sandbox; the permission review is an app-level per-run approval, not OS-enforced isolation. Reports omit raw argv values and redact common labelled and known invocation secrets. This adapter only starts declared Python, Bash or Node.js entry points. MCP servers, HTTP/API connectors, standalone binaries and workflow descriptors require their own reviewed adapters. Scripts may still invoke available CLI programs within the guest runtime.',
        'parameters': {
          'type': 'object',
          'properties': {
            'task': {
              'type': 'string',
              'minLength': 1,
              'description': 'Original task brief used to rebuild and validate the composition plan. Kelivo compacts oversized text to 8000 Unicode characters.',
            },
            'selection_mode': {
              'type': 'string',
              'enum': ['explicit', 'all_enabled'],
              'description': 'Selection mode from the preceding skill_compose plan. Use all_enabled when that plan included every enabled Skill; defaults to explicit.',
              'default': 'explicit',
            },
            'skill_id': {
              'type': 'string',
              'minLength': 1,
              'maxLength': 100,
              'description': 'Enabled installed Skill selected by the composition planner.',
            },
            'entry_point': {
              'type': 'string',
              'minLength': 1,
              'maxLength': 240,
              'description': 'Exact Skill-relative script path listed in its local_script Capability Descriptor.',
            },
            'runtime_profile_id': {
              'type': 'string',
              'minLength': 1,
              'maxLength': 64,
              'description': 'Ready extension Runtime Profile whose owner_id is this Skill ID.',
            },
            'arguments': {
              'type': 'array',
              'maxItems': 64,
              'items': {'type': 'string', 'maxLength': 4096},
              'description': 'Arguments passed as individually quoted strings, not shell fragments.',
            },
            'inputs': {
              'type': 'object',
              'maxProperties': 64,
              'description': 'JSON-compatible input values supplied to the script through KELIVO_SKILL_INPUT_JSON.',
              'additionalProperties': true,
            },
            'input_files': {
              'type': 'object',
              'maxProperties': 32,
              'description': 'Map of declared input artifact names to existing workspace-relative file paths. Files are copied into the temporary run area.',
              'additionalProperties': {'type': 'string', 'maxLength': 1024},
            },
            'expected_outputs': {
              'type': 'object',
              'maxProperties': 32,
              'description': 'Map of every declared output artifact name to its relative path under the run output directory.',
              'additionalProperties': {'type': 'string', 'maxLength': 240},
            },
            'expected_output_types': {
              'type': 'object',
              'maxProperties': 32,
              'description': 'Optional MIME type assertions for expected output artifacts. Kelivo checks the file type against the declared extension/signature before recording it.',
              'additionalProperties': {'type': 'string', 'maxLength': 100},
            },
            'timeout_seconds': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 3600,
              'description': 'Requested timeout; the active Runtime Profile limit is always enforced as the upper bound.',
            },
          },
          'required': [
            'task',
            'skill_id',
            'entry_point',
            'runtime_profile_id',
          ],
          'additionalProperties': false,
        },
      },
    },
  ];
}
