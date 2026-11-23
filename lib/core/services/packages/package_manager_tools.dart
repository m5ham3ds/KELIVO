/// The universal package manager is exposed as one structured conversation
/// tool. Mutating actions are approved by ToolCallPermission in the handler.
abstract final class PackageManagerToolNames {
  static const String manage = 'package_manager';

  static const Set<String> requiresManualApprovalActions = {
    'install',
    'upgrade',
    'remove',
    'pin',
    'unpin',
  };

  static const Set<String> all = {manage};
}

/// Resolves canonical media utility names to unique system packages.
/// FFmpeg and FFprobe intentionally map to the same ffmpeg package.
abstract final class PackageManagerEnvironmentTools {
  static const Map<String, String> _packages = {
    'ffmpeg': 'ffmpeg',
    'ffprobe': 'ffmpeg',
    'yt-dlp': 'yt-dlp',
    'mediainfo': 'mediainfo',
    'ffmpegthumbnailer': 'ffmpegthumbnailer',
    'imagemagick': 'imagemagick',
  };

  static Map<String, dynamic> resolve(
    Map<String, dynamic> arguments, {
    required String? distro,
  }) {
    final raw = arguments['tools'];
    if (raw == null) return arguments;
    if (raw is! List || raw.isEmpty || raw.length > 6) {
      throw const FormatException('environment_tools_must_be_one_to_six_names');
    }
    final requested = <String>[];
    final packages = <String>[];
    for (final value in raw) {
      if (value is! String) {
        throw const FormatException('invalid_environment_tool_name');
      }
      final canonical = value.trim().toLowerCase();
      final package = _packages[canonical];
      if (package == null) {
        throw FormatException('unsupported_environment_tool:$value');
      }
      requested.add(canonical);
      if (!packages.contains(package)) packages.add(package);
    }
    return <String, dynamic>{
      ...arguments,
      'ecosystem': 'system',
      'manager': (distro ?? '').toLowerCase() == 'alpine' ? 'apk' : 'apt',
      'scope': 'runtime',
      'packages': packages,
      'requested_tools': requested.toSet().toList(growable: false),
    }..remove('package');
  }
}

abstract final class PackageManagerToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    {
      'type': 'function',
      'function': {
        'name': PackageManagerToolNames.manage,
        'description':
            'Detect and manage packages in the Android/Linux PRoot runtime. Supports apt/apk, pip/uv, npm/pnpm/yarn/bun; inspect or plan before changing packages. Use registry package names only; package URLs, git sources, arbitrary shell commands and remote scripts are rejected. Actions install/upgrade/remove/pin/unpin always require a fresh explicit manual user approval, including when Full Access is enabled. Python source builds and Node lifecycle scripts are disabled by default; enable them only for a trusted package after explaining the risk. OS package manager changes affect the shared PRoot RootFS; Python and Node dependencies for scope=extension require an exact Skill-owned profile_id; KELIVO refuses to fall back to a shared extension package root. Project defaults may be used only in project scope. Runtime-scoped apt/apk changes the shared RootFS. Profile-scoped dependency mutations create a verified pre-change snapshot and attempt restore on failure. Snapshots exclude shared apt/apk changes; use runtime_profile snapshot actions for manual rollback.',
        'parameters': {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': [
                'plan',
                'check',
                'install',
                'upgrade',
                'remove',
                'pin',
                'unpin',
                'list',
              ],
              'description':
                  'plan/check are read-only; install/upgrade/remove mutate the runtime; pin/unpin update the package ledger; list shows installed records and recent history.',
              'default': 'plan',
            },
            'ecosystem': {
              'type': 'string',
              'enum': ['system', 'python', 'node'],
              'description':
                  'Select the package ecosystem when no manifest identifies it. Use system for apt/apk, python for PyPI, node for npm-compatible registries.',
            },
            'manager': {
              'type': 'string',
              'enum': [
                'auto',
                'apt',
                'apk',
                'pip',
                'uv',
                'npm',
                'pnpm',
                'yarn',
                'bun',
              ],
              'description': 'Choose a manager or let Kelivo detect it.',
              'default': 'auto',
            },
            'scope': {
              'type': 'string',
              'enum': ['runtime', 'global', 'project', 'extension', 'task'],
              'description':
                  'Installation scope. apt/apk are runtime-scoped only and modify the shared active rootfs. Python/Node are isolated per runtime/project/extension/task scope, or inside the selected matching Runtime Profile.',
              'default': 'runtime',
            },
            'package': {
              'type': 'string',
              'description': 'One registry package name for a single-package action.',
              'maxLength': 214,
            },
            'tools': {
              'type': 'array',
              'description': 'Canonical media utilities: ffmpeg, ffprobe, yt-dlp, mediainfo, ffmpegthumbnailer, imagemagick. FFmpeg and FFprobe map to one package.',
              'items': {
                'type': 'string',
                'enum': ['ffmpeg', 'ffprobe', 'yt-dlp', 'mediainfo', 'ffmpegthumbnailer', 'imagemagick'],
              },
              'maxItems': 6,
              'uniqueItems': true,
            },
            'packages': {
              'type': 'array',
              'description': 'Multiple registry package names (maximum 24).',
              'items': {'type': 'string', 'maxLength': 214},
              'maxItems': 24,
              'uniqueItems': true,
            },
            'version': {
              'type': 'string',
              'description': 'Exact version only; ranges and dist-tags are not accepted as pins.',
              'maxLength': 64,
            },
            'skill_id': {
              'type': 'string',
              'description':
                  'Optional installed Skill ID. Reads only its SKILL.md metadata keys kelivo.package-manager and kelivo.packages; declared packages are never installed until action=install and user approval.',
              'maxLength': 64,
            },
            'manifest_path': {
              'type': 'string',
              'description':
                  'Optional path inside the active workspace to requirements.txt, pyproject.toml or package.json. It is parsed read-only. May be combined with skill_id only when both use the same ecosystem and manager.',
              'maxLength': 1024,
            },
            'extension_id': {
              'type': 'string',
              'description': 'Optional when skill_id is provided; defaults to skill_id when scope=extension.',
              'maxLength': 64,
            },
            'profile_id': {
              'type': 'string',
              'description': 'Required for Python/Node operations with scope=extension. It must be a Runtime Profile owned by the same Skill and include the requested ecosystem. Use runtime_profile to list/create/inspect it first. KELIVO rejects extension installs without it.',
              'maxLength': 64,
            },
            'task_id': {
              'type': 'string',
              'description': 'Required when scope=task.',
              'maxLength': 64,
            },
            'scope_key': {
              'type': 'string',
              'description': 'Optional exact scope key for filtering the local ledger.',
              'maxLength': 128,
            },
            'verify_binaries': {
              'type': 'array',
              'description':
                  'Optional executable names to check on PATH after install/upgrade.',
              'items': {'type': 'string', 'maxLength': 128},
              'maxItems': 24,
              'uniqueItems': true,
            },
            'allow_install_scripts': {
              'type': 'boolean',
              'description':
                  'Explicitly allow Node package lifecycle scripts. Disabled by default.',
              'default': false,
            },
            'allow_source_builds': {
              'type': 'boolean',
              'description':
                  'Explicitly allow Python source distributions and build steps. Disabled by default; compatible prebuilt wheels are preferred for ARM64.',
              'default': false,
            },
          },
          'required': ['action'],
        },
      },
    },
  ];
}
