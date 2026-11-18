
abstract final class RuntimeProfileToolNames {
  static const String manage = 'runtime_profile';
  static const Set<String> all = {manage};
}

abstract final class RuntimeProfileToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    {
      'type': 'function',
      'function': {
        'name': RuntimeProfileToolNames.manage,
        'description':
            'Create and manage logical-isolation Shell/Python/Node Runtime Profiles for the active workspace or an installed Skill. Profiles have independent package roots and environment variables, a disposable per-run TMPDIR, a persistent KELIVO_TASK_OUTPUT_DIR, persisted process history, and dependency snapshots. Snapshot/restore covers profile-owned Python/Node package roots and lockfiles only; apt/apk changes the shared PRoot RootFS and is excluded. Timeouts are enforced by the runtime; process, virtual-memory and file limits are best-effort PRoot shell limits, and temporary storage is checked after a run, not a kernel quota. PRoot profiles are local to this Android device; they are not remote services or a kernel security boundary. Create/remove/default/cancel/snapshot/restore/delete operations require user approval.',
        'parameters': {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['create', 'list', 'inspect', 'set_default', 'clear_default', 'remove', 'processes', 'cancel', 'snapshot', 'snapshots', 'restore_snapshot', 'delete_snapshot'],
              'description': 'Operation to perform.',
            },
            'profile_id': {
              'type': 'string',
              'description': 'Existing profile ID for inspect, set_default, remove, snapshot or snapshots.',
              'maxLength': 64,
            },
            'name': {
              'type': 'string',
              'description': 'Human-readable name for a new profile.',
              'maxLength': 80,
            },
            'scope': {
              'type': 'string',
              'enum': ['project', 'extension'],
              'default': 'project',
            },
            'owner_id': {
              'type': 'string',
              'description': 'Required for extension profiles and must identify an installed Skill; project profiles use the active workspace ID.',
              'maxLength': 64,
            },
            'ecosystems': {
              'type': 'array',
              'items': {'type': 'string', 'enum': ['shell', 'python', 'node']},
              'minItems': 1,
              'maxItems': 3,
              'uniqueItems': true,
            },
            'environment': {
              'type': 'object',
              'description': 'Optional non-secret uppercase environment variables. PATH/HOME/TMP and secret-like keys are rejected.',
              'additionalProperties': {'type': 'string', 'maxLength': 4096},
            },
            'limits': {
              'type': 'object',
              'properties': {
                'maxDurationSeconds': {'type': 'integer', 'minimum': 1, 'maximum': 3600},
                'maxCpuSeconds': {'type': 'integer', 'minimum': 1, 'maximum': 3600, 'description': 'Best-effort CPU time limit using shell RLIMIT_CPU.'},
                'maxConcurrentRuns': {'type': 'integer', 'minimum': 1, 'maximum': 4},
                'maxProcesses': {'type': 'integer', 'minimum': 8, 'maximum': 256},
                'maxMemoryMegabytes': {'type': 'integer', 'minimum': 128, 'maximum': 8192, 'description': 'Best-effort virtual-memory limit in PRoot, not a guaranteed physical RAM quota.'},
                'maxTempMegabytes': {'type': 'integer', 'minimum': 16, 'maximum': 4096, 'description': 'Checked after a run; not a live filesystem quota.'},
                'maxOutputMegabytes': {'type': 'integer', 'minimum': 1, 'maximum': 8192, 'description': 'Maximum output budget; checked after the command or video render completes.'},
                'maxFileMegabytes': {'type': 'integer', 'minimum': 1, 'maximum': 2048},
              },
            },
            'share_base_tools': {
              'type': 'boolean',
              'description': 'Add /usr/local and system administration tool directories to PATH. /usr/bin and /bin remain available as the minimum runtime toolchain.',
              'default': true,
            },
            'snapshot_id': {
              'type': 'string',
              'description': 'Existing dependency snapshot ID for restore_snapshot or delete_snapshot.',
              'maxLength': 64,
            },
            'description': {
              'type': 'string',
              'description': 'Optional human-readable label for a dependency snapshot.',
              'maxLength': 120,
            },
            'run_id': {
              'type': 'string',
              'description': 'Runtime run ID for cancellation.',
              'maxLength': 64,
            },
          },
          'required': ['action'],
        },
      },
    },
  ];
}

