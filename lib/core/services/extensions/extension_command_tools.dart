/// Tool schemas exposed to the assistant for conversation-first extension
/// management. Phase 3 supports standard Agent Skills from GitHub, skills.sh
/// and local sources; other extension kinds need later dedicated adapters.
abstract final class ExtensionCommandToolNames {
  static const String search = 'extension_search';
  static const String inspect = 'extension_inspect';
  static const String install = 'extension_install';
  static const String update = 'extension_update';
  static const String checkUpdates = 'extension_check_updates';
  static const String enable = 'extension_enable';
  static const String disable = 'extension_disable';
  static const String remove = 'extension_remove';
  static const String rollback = 'extension_rollback';
  static const String list = 'extension_list';

  static const Set<String> requiresManualApproval = {
    install,
    update,
    enable,
    disable,
    remove,
    rollback,
  };

  static const Set<String> all = {
    search,
    inspect,
    install,
    update,
    checkUpdates,
    enable,
    disable,
    remove,
    rollback,
    list,
  };
}

abstract final class ExtensionCommandToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    _tool(
      ExtensionCommandToolNames.search,
      'Search installed Agent Skills, public GitHub repositories, or the skills.sh catalog. Results are discovery candidates, not guaranteed validated Skills.',
      {
        'query': _string('Search terms. Use a skill name or capability.'),
        'scope': _stringEnum('Where to search.', const [
          'all',
          'installed',
          'github',
          'catalog',
        ]),
        'limit': _integer(
          'Maximum results, from 1 to 10.',
          minimum: 1,
          maximum: 10,
        ),
      },
      const ['query'],
    ),
    _tool(
      ExtensionCommandToolNames.inspect,
      'Inspect an installed Skill by id or preview a GitHub (public/private when protected access is configured), skills.sh, or local Skill source without executing scripts. Provide exactly one of id or source.',
      {
        'id': _string('Installed Skill id.'),
        'source': _string(
          'GitHub repository/branch/tag/commit/subfolder URL (including private repositories with protected access), skills.sh Skill URL, or local Skill path within the bound workspace.',
        ),
      },
    ),
    _tool(
      ExtensionCommandToolNames.install,
      'Install Agent Skills from a GitHub repository/branch/tag/commit/subfolder (including private repositories with protected access), a GitHub-backed skills.sh catalog URL, or a local SKILL.md/.skill file, a Skill folder, a standard repository ZIP, or a Skill bundle ZIP containing one or more nested Skill ZIPs. Direct GitHub blob/raw links to `.skill` and `.zip` files are supported. IMPORTANT: when the user asks to install an attached ZIP and the message gives a local attachment path such as `/chat/attachments/animation-director.zip`, call extension_install directly with kind=skill and that exact path as source. Do not call list_dir or read_file first; the importer handles ZIP inspection, selection and extraction. Multi-Skill sources install all compatible Skills by default; provide skill_paths for GitHub repository subsets. All companion references, assets, examples, scripts and metadata files are preserved in the Skill directory or retained as package-level shared resources. No scripts are executed.',
      {
        'kind': _stringEnum('Extension kind supported in this phase.', const [
          'skill',
        ]),
        'source': _string(
          'GitHub repository/branch/subfolder URL or direct .skill/.zip blob/raw file URL, skills.sh/{owner}/{repo}/{slug} URL, or local .md/.skill/.zip/folder path inside the bound workspace. For an attached ZIP, pass its exact `/chat/attachments/<filename>.zip` path.',
        ),
        'skill_paths': {
          'type': 'array',
          'description': 'Optional GitHub repository-relative Skill folders to install. Omit to install every compatible Skill found in the repository.',
          'items': {'type': 'string'},
          'uniqueItems': true,
          'maxItems': 128,
        },
        'enable_after_install': _boolean(
          'Enable each installed Skill after installation. Defaults to true.',
        ),
      },
      const ['source'],
    ),
    _tool(
      ExtensionCommandToolNames.update,
      'Update an installed Skill independently from its recorded GitHub or skills.sh catalog source. User-created Skill Packs are organizational groups and never take ownership of member updates; only repository-detected packs with one shared upstream source may be refreshed together. Set all=true to update every remotely updateable Skill and repository-detected pack; user-created packs are ignored as groups and each member remains eligible for an individual update. Otherwise provide id to update exactly one Skill. Omit source to use registered metadata; only supply source when the user explicitly provides a replacement GitHub or skills.sh Skill URL. A rollback snapshot is created for every replaced Skill.',
      {
        'id': _string('Installed Skill id. Required unless all=true.'),
        'source': _string('Optional replacement GitHub repository or skills.sh Skill URL.'),
        'all': _boolean('Update all remotely updateable Skills and repository-detected packs; manually created Packs do not combine member updates. Defaults to false.'),
      },
      const [],
    ),
    _tool(
      ExtensionCommandToolNames.checkUpdates,
      'Check remote revisions for one installed Skill or all remotely tracked Skills without downloading files into the installed Skills directory, changing metadata, creating rollback snapshots, or applying updates. Provide id to check one Skill, or all=true to check every remotely tracked Skill. After this read-only check, use extension_update only as a separate action requiring fresh explicit user approval.',
      {
        'id': _string('Optional installed Skill id. Required unless all=true.'),
        'all': _boolean('Check all installed Skills with a supported remote origin. Defaults to false.'),
      },
    ),
    _tool(
      ExtensionCommandToolNames.enable,
      'Enable an installed Skill so it can be selected for assistant context.',
      {'id': _string('Installed Skill id.')},
      const ['id'],
    ),
    _tool(
      ExtensionCommandToolNames.disable,
      'Disable an installed Skill without deleting its files.',
      {'id': _string('Installed Skill id.')},
      const ['id'],
    ),
    _tool(
      ExtensionCommandToolNames.remove,
      'Remove an installed Skill and its local files. This cannot be undone unless a separate exported copy exists.',
      {'id': _string('Installed Skill id.')},
      const ['id'],
    ),
    _tool(
      ExtensionCommandToolNames.rollback,
      'Restore the most recent pre-update snapshot for an installed Skill.',
      {'id': _string('Installed Skill id.')},
      const ['id'],
    ),
    _tool(
      ExtensionCommandToolNames.list,
      'List every installed Skill independently and report any Skill Packs separately. The enabled/disabled filter applies to each original Skill toggle; pack-based effective availability is reported separately and never hides or replaces the original Skill.',
      {
        'status': _stringEnum('Optional Skill status filter.', const [
          'all',
          'enabled',
          'disabled',
        ]),
        'include_history': _boolean(
          'Include recent installation/update operations. Defaults to true.',
        ),
      },
    ),
  ];

  static Map<String, dynamic> _tool(
    String name,
    String description,
    Map<String, dynamic> properties, [
    List<String> required = const [],
  ]) {
    final parameters = <String, dynamic>{
      'type': 'object',
      'properties': properties,
      'additionalProperties': false,
      if (required.isNotEmpty) 'required': required,
    };
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': parameters,
      },
    };
  }

  static Map<String, dynamic> _string(String description) => {
    'type': 'string',
    'description': description,
  };

  static Map<String, dynamic> _stringEnum(
    String description,
    List<String> values,
  ) => {'type': 'string', 'description': description, 'enum': values};

  static Map<String, dynamic> _integer(
    String description, {
    required int minimum,
    required int maximum,
  }) => {
    'type': 'integer',
    'description': description,
    'minimum': minimum,
    'maximum': maximum,
  };

  static Map<String, dynamic> _boolean(String description) => {
    'type': 'boolean',
    'description': description,
  };
}
