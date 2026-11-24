import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../api/tool_call_cancellation.dart';
import '../extensions/extension_command_tools.dart';
import '../extensions/extension_operation_repository.dart';
import '../extensions/extension_registry_repository.dart';
import '../extensions/extension_permission_policy.dart';
import '../skills/github_skill_ref.dart';
import '../skills/skill_frontmatter.dart';
import '../skills/skill_requirements.dart';
import '../skills/skills_service.dart';
import '../../providers/environment_provider.dart';
import '../workspace/tool_run_registry.dart';
import '../workspace/workspace_runtime.dart';
import '../workspace/workspace_tool_context.dart';

/// Executes extension-management tools requested from the active conversation.
///
/// Phase 3 supports standard Agent Skills from GitHub, skills.sh and local
/// sources. Other extension kinds remain deferred until their own adapters exist.
final class ConversationalExtensionService {
  ConversationalExtensionService({
    required this.skills,
    required this.registry,
    required this.operations,
    this.toolRuns,
    this.conversationId,
    this.onProgress,
    this.runtimeProvider,
    this.environment,
  });

  final SkillsService skills;
  final ExtensionRegistryRepository registry;
  final ExtensionOperationRepository operations;
  final ToolRunRegistry? toolRuns;
  final String? conversationId;
  final void Function(SkillImportProgress progress)? onProgress;
  final WorkspaceRuntimeProvider? runtimeProvider;
  final EnvironmentProvider? environment;

  Future<Map<String, Object?>?> _requirementsAssessment(
    Map<String, Object?>? importReport,
  ) async {
    if (importReport == null) return null;
    WorkspaceRuntime? runtime;
    try {
      runtime = await runtimeProvider?.ensureInitialized(
        timeout: const Duration(seconds: 8),
      );
    } catch (_) {
      runtime = null;
    }
    try {
      final assessment = await SkillEnvironmentRequirementProbe.assess(
        importReport: importReport,
        runtime: runtime,
        environment: environment,
      );
      final probedSourceDigest = importReport['sourceDigest']?.toString();
      if (probedSourceDigest != null) assessment['sourceDigest'] = probedSourceDigest;
      final skillId = importReport['skillId']?.toString();
      if (skillId != null && skillId.isNotEmpty) {
        await skills.saveEnvironmentAssessment(skillId, assessment);
      }
      return assessment;
    } catch (error) {
      final raw = importReport['requirements'];
      final fallback = raw is Map
          ? Map<String, Object?>.from(raw)
          : <String, Object?>{};
      fallback['readiness'] = 'probe_failed';
      fallback['probeError'] = error.runtimeType.toString();
      fallback['notes'] = <String>[
        ...(fallback['notes'] as List? ?? const []).whereType<String>(),
        'Live environment checking failed safely; use the static requirement inventory and do not assume availability.',
      ];
      return fallback;
    }
  }

  Future<String> handle(
    String name,
    Map<String, dynamic> args, {
    WorkspaceToolContext? workspaceContext,
    String? toolCallId,
  }) async {
    await skills.loaded;
    switch (name) {
      case ExtensionCommandToolNames.list:
        return _list(args);
      case ExtensionCommandToolNames.search:
        return _search(args);
      case ExtensionCommandToolNames.inspect:
        return _inspect(args, workspaceContext);
      case ExtensionCommandToolNames.install:
        return _install(args, workspaceContext, toolCallId);
      case ExtensionCommandToolNames.update:
        return _update(args, toolCallId);
      case ExtensionCommandToolNames.checkUpdates:
        return _checkUpdates(args);
      case ExtensionCommandToolNames.enable:
        return _toggle(args, true, toolCallId);
      case ExtensionCommandToolNames.disable:
        return _toggle(args, false, toolCallId);
      case ExtensionCommandToolNames.remove:
        return _remove(args, toolCallId);
      case ExtensionCommandToolNames.rollback:
        return _rollback(args, toolCallId);
      default:
        throw FormatException('Unknown extension command: $name');
    }
  }

  Future<String> _checkUpdates(Map<String, dynamic> args) async {
    final id = (args['id'] ?? '').toString().trim();
    final all = args['all'] == true;
    if (id.isEmpty && !all) {
      throw const FormatException('Provide id or set all=true.');
    }
    if (id.isNotEmpty && all) {
      throw const FormatException('Provide either id or all=true, not both.');
    }
    final results = await skills.checkUpdateAvailability(
      skillId: id.isEmpty ? null : id,
      all: all,
    );
    final updateCount = results.where((item) => item['updateAvailable'] == true).length;
    final unknownCount = results.where((item) =>
        item['status'] == 'unknown' || item['status'] == 'unsupported').length;
    final totalInstalled = skills.skills.length;
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'readOnly': true,
      'filesChanged': false,
      'updatesFound': updateCount,
      'unknownOrUnavailable': unknownCount,
      'checkedSkills': results.length,
      'totalInstalledSkills': totalInstalled,
      'truncated': all && totalInstalled > results.length,
      'results': results,
      'nextStep': updateCount > 0
          ? 'No update has been installed. Ask the user before calling extension_update; that operation always requires a fresh manual approval.'
          : 'No remote update was applied.',
    });
  }

  Future<String> _list(Map<String, dynamic> args) async {
    final status = (args['status'] ?? 'all').toString();
    if (!const {'all', 'enabled', 'disabled'}.contains(status)) {
      throw const FormatException('status must be all, enabled, or disabled');
    }
    final includeHistory = args['include_history'] != false;
    final all = skills.skills;
    final packsBySkillId = <String, List<SkillPack>>{};
    for (final pack in skills.skillPacks) {
      for (final skillId in pack.skillIds) {
        packsBySkillId.putIfAbsent(skillId, () => <SkillPack>[]).add(pack);
      }
    }

    final filtered = all.where((skill) {
      // `status` filters the original Skill's own switch. Pack activation is
      // reported separately as effective availability and never replaces the
      // standalone state shown to the user or assistant.
      return switch (status) {
        'enabled' => skill.record.enabled,
        'disabled' => !skill.record.enabled,
        _ => true,
      };
    }).toList();
    final buffer = StringBuffer()
      ..writeln('Found ${filtered.length} installed Skills.')
      ..writeln();

    if (filtered.isEmpty) {
      buffer.writeln('No Skills match this filter.');
    } else {
      for (final skill in filtered) {
        final memberPacks = packsBySkillId[skill.record.id] ?? const <SkillPack>[];
        final enabledByPack = memberPacks.any((pack) => pack.enabled);
        final effectiveLabel = skill.record.enabled
            ? 'enabled standalone'
            : enabledByPack
                ? 'enabled by pack'
                : 'disabled';
        buffer
          ..writeln(
            '- **${skill.name}** (`${skill.record.id}`) — '
            'standalone: ${skill.record.enabled ? 'enabled' : 'disabled'}; '
            'effective: $effectiveLabel; '
            'source: ${skill.record.source.name}; '
            'used: ${skill.record.useCount} times; '
            'rollback: ${skills.hasRollback(skill.record.id) ? 'available' : 'not available'}',
          )
          ..writeln('  ${skill.description}');
        if (memberPacks.isNotEmpty) {
          buffer.writeln(
            '  Packs: ${memberPacks.map((pack) =>
                '**${pack.name}** (/${pack.shortcut}, ${pack.enabled ? 'enabled' : 'disabled'})').join('; ')}',
          );
        }
      }
    }

    // Report packs as additional shortcuts, not as containers that replace
    // their members in the standalone Skill inventory.
    if (skills.skillPacks.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Skill Packs');
      for (final pack in skills.skillPacks) {
        final names = pack.skillIds.map((id) {
          final member = all.where((skill) => skill.record.id == id).firstOrNull;
          return member?.name ?? id;
        });
        buffer.writeln(
          '- **${pack.name}** (/${pack.shortcut}) — '
          '${pack.enabled ? 'enabled' : 'disabled'}; '
          'members: ${names.join(', ')}',
        );
      }
    }

    if (includeHistory) {
      final history = await operations.list(limit: 12);
      buffer
        ..writeln()
        ..writeln('## Recent Extension Operations');
      if (history.isEmpty) {
        buffer.writeln('No extension operations recorded yet.');
      } else {
        for (final operation in history) {
          buffer.writeln(
            '- `${operation.operation}` ${operation.target}: '
            '${operation.status.name}'
            '${operation.phase == null ? '' : ' (${operation.phase})'}'
            '${operation.errorCode == null ? '' : ' — ${operation.errorCode}'}',
          );
        }
      }
    }
    return buffer.toString();
  }

  Future<String> _search(Map<String, dynamic> args) async {
    final query = _requiredString(args, 'query', max: 160);
    final scope = (args['scope'] ?? 'all').toString();
    final limit = ((args['limit'] as num?)?.toInt() ?? 8).clamp(1, 10).toInt();
    if (!const {'all', 'installed', 'github', 'catalog'}.contains(scope)) {
      throw const FormatException('scope must be all, installed, github, or catalog');
    }
    final result = <String, Object?>{'query': query};
    if (scope == 'all' || scope == 'installed') {
      final installedMatches = skills.searchInstalled(query);
      result['installedSkills'] = [
        for (final skill in installedMatches.take(limit))
          {
            'id': skill.record.id,
            'name': skill.name,
            'description': skill.description,
            'enabled': skill.record.enabled,
            'source': skill.record.source.name,
          },
      ];
      result['installedSkillsTotal'] = installedMatches.length;
      result['installedSkillsTruncated'] = installedMatches.length > limit;
    }
    if (scope == 'all' || scope == 'github') {
      try {
        result['githubRepositories'] = await skills.searchGitHubRepositories(
          query,
          limit: limit,
        );
        result['githubNote'] =
            'Public GitHub repository candidates only. Inspect a candidate before installation; search results are not proof that the repository contains a valid Skill.';
      } catch (error) {
        result['githubSearchError'] = _safeError(error);
      }
    }
    if (scope == 'all' || scope == 'catalog') {
      try {
        final entries = await skills.searchSkillsCatalog(query, limit: limit);
        result['skillsShCatalog'] = [
          for (final entry in entries)
            {
              'id': entry.id,
              'name': entry.name,
              'description': entry.description,
              'source': entry.source,
              'installs': entry.installs,
              'url': entry.url,
            },
        ];
        result['catalogNote'] =
            'Catalog results are discovery candidates. Inspect a Skill before installation; only GitHub-backed catalog entries are currently importable.';
      } catch (error) {
        result['catalogSearchError'] = _safeError(error);
      }
    }
    return const JsonEncoder.withIndent('  ').convert(result);
  }

  List<Map<String, Object?>> _reviewSkillPermissions(String markdown) {
    final frontmatter = SkillFrontmatter.parse(markdown);
    if (frontmatter.parseError != null ||
        !frontmatter.hasFrontmatter ||
        !frontmatter.metadataIsValid) {
      return ExtensionPermissionPolicy.review(const ['skill.frontmatter.invalid']);
    }
    final raw = frontmatter.metadata['kelivo.permissions'] ?? '';
    final requested = raw
        .split(RegExp(r'[,;\s]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    return ExtensionPermissionPolicy.review(requested);
  }

  Future<String> _inspect(
    Map<String, dynamic> args,
    WorkspaceToolContext? workspaceContext,
  ) async {
    final id = (args['id'] ?? '').toString().trim();
    final source = (args['source'] ?? '').toString().trim();
    if ((id.isEmpty && source.isEmpty) ||
        (id.isNotEmpty && source.isNotEmpty)) {
      throw const FormatException('Provide exactly one of id or source.');
    }
    if (id.isNotEmpty) {
      final skill = _findSkill(id);
      final record = await registry.get('skill', id);
      final markdown = await skills.readSkillMarkdown(id);
      final permissionReview = _reviewSkillPermissions(markdown);
      final importReport = await skills.getImportReportWithRequirements(id);
      final requirements = await _requirementsAssessment(importReport);
      return [
        '## ${skill.name}',
        '',
        '- ID: `${skill.record.id}`',
        '- Status: ${skill.record.enabled ? 'enabled' : 'disabled'}',
        '- Source: ${skill.record.source.name}',
        '- Description: ${skill.description}',
        '- Installed: ${skill.record.installedAt.toIso8601String()}',
        '- Last updated: ${skill.record.updatedAt.toIso8601String()}',
        '- Rollback: ${skills.hasRollback(id) ? 'available' : 'not available'}',
        if (record?.source.uri != null) '- Source URL: ${record!.source.uri}',
        '',
        '### Permission review',
        if (permissionReview.isEmpty) '- No Kelivo-specific permissions declared.',
        for (final permission in permissionReview)
          '- `${permission['permission']}` — ${permission['risk']} risk; explicit approval required; not granted automatically${permission['blockedUntilReviewed'] == true ? '; blocked until reviewed' : ''}.',
        '',
        requirements == null
            ? '### Environment requirements\nNo import requirement report is available.'
            : SkillEnvironmentRequirementProbe.toMarkdown(requirements),
        '',
        '### SKILL.md',
        '```markdown',
        markdown,
        '```',
      ].join('\n');
    }
    if (_isSkillsShSource(source)) {
      final preview = await skills.inspectSkillsCatalog(_skillsShId(source));
      return const JsonEncoder.withIndent('  ').convert(preview);
    }
    if (_isGitHubSource(source)) {
      final preview = await skills.inspectGitHubSkill(source);
      return const JsonEncoder.withIndent('  ').convert(preview);
    }
    final path = await _resolveLocalSource(source, workspaceContext);
    final preview = await skills.inspectLocalSource(path);
    return const JsonEncoder.withIndent('  ').convert(preview);
  }

  Future<String> _install(
    Map<String, dynamic> args,
    WorkspaceToolContext? workspaceContext,
    String? toolCallId,
  ) async {
    final kind = (args['kind'] ?? 'skill').toString();
    if (kind != 'skill') {
      throw FormatException(
        'The "$kind" extension installer is not implemented yet. Phase 3 installs Agent Skills only; other extension kinds require their dedicated adapters in later phases.',
      );
    }
    final source = _requiredString(args, 'source', max: 2048);
    final enableAfterInstall = args['enable_after_install'] != false;
    return _runTracked(
      operation: 'install',
      kind: 'skill',
      target: _safeHistorySource(source),
      source: _safeHistorySource(source),
      toolCallId: toolCallId,
      action: (cancelSignal, onProgress) async {
        final List<Skill> installed;
        if (_isSkillsShSource(source)) {
          final skill = await skills.importFromSkillsCatalog(_skillsShId(source));
          installed = [skill];
          onProgress(const SkillImportProgress(SkillImportPhase.installing));
        } else if (_isGitHubSource(source)) {
          final rawPaths = args['skill_paths'];
          Set<String>? requestedPaths;
          if (rawPaths != null) {
            if (rawPaths is! List || rawPaths.length > 128 ||
                rawPaths.any((value) => value is! String || value.trim().isEmpty) ||
                rawPaths.toSet().length != rawPaths.length) {
              throw const FormatException(
                'skill_paths must be a unique array of repository-relative Skill paths.',
              );
            }
            requestedPaths = rawPaths.cast<String>().toSet();
          }
          final selectedPaths = requestedPaths;
          installed = await skills.importFromGitHubRepository(
            source,
            chooseSkills: (candidates) async {
              if (selectedPaths != null) return selectedPaths;
              return <String>{
                for (final candidate in candidates)
                  if (candidate.compatibility.isImportable) candidate.path,
              };
            },
            onProgress: onProgress,
            cancelSignal: cancelSignal,
          );
        } else {
          final localPath = await _resolveLocalSource(source, workspaceContext);
          final entityType = await FileSystemEntity.type(
            localPath,
            followLinks: false,
          );
          if (entityType == FileSystemEntityType.directory) {
            final skill = await skills.importFromDirectory(
              localPath,
              onProgress: onProgress,
              cancelSignal: cancelSignal,
            );
            installed = [skill];
          } else {
            installed = await skills.importSkillsFromFile(
              localPath,
              chooseSkills: (candidates) async {
                final compatible = candidates
                    .where((candidate) => candidate.compatibility.isImportable)
                    .toList(growable: false);
                if (compatible.isEmpty && candidates.isNotEmpty) {
                  final details = candidates.take(8).map((candidate) {
                    final reasons = candidate.compatibility.errors.isEmpty
                        ? const <String>['unsupported Skill metadata']
                        : candidate.compatibility.errors.take(4);
                    return '${candidate.name} (${candidate.path}): '
                        '${reasons.join('; ')}';
                  }).join(' | ');
                  throw FormatException(
                    'No compatible Agent Skills were found in this source. '
                    'Check that each SKILL.md name matches its containing '
                    'Skill directory and that the required metadata is valid. '
                    'Details: $details',
                  );
                }
                return <String>{
                  for (final candidate in compatible) candidate.path,
                };
              },
              onProgress: onProgress,
              cancelSignal: cancelSignal,
            );
          }
          onProgress(const SkillImportProgress(SkillImportPhase.installing));
        }
        if (installed.isEmpty) {
          throw const FormatException(
            'No compatible Agent Skills were selected from this source.',
          );
        }
        if (!enableAfterInstall) {
          for (final skill in installed) {
            await skills.setEnabled(skill.record.id, false);
          }
        }
        final lines = <String>[
          'Installed ${installed.length} Agent Skill${installed.length == 1 ? '' : 's'}:',
        ];
        for (final skill in installed) {
          final current = _findSkill(skill.record.id);
          lines.add(
            '- **${current.name}** (`${current.record.id}`) — ${current.record.enabled ? 'enabled' : 'disabled'}',
          );
          final importReport = await skills.getImportReportWithRequirements(current.record.id);
          final requirements = await _requirementsAssessment(importReport);
          if (requirements != null) {
            lines
              ..add('')
              ..add(SkillEnvironmentRequirementProbe.toMarkdown(requirements));
          }
          final importNotes = (importReport?['completenessNotes'] as List? ?? const [])
              .whereType<String>()
              .toList(growable: false);
          for (final note in importNotes) {
            lines.add('  - Import note: $note');
          }
          final markdown = await skills.readSkillMarkdown(current.record.id);
          final permissionReview = _reviewSkillPermissions(markdown);
          if (permissionReview.isEmpty) {
            lines.add('  - Permissions: no Kelivo-specific permissions declared.');
          } else {
            lines.add('  - Permission review:');
            for (final permission in permissionReview) {
              lines.add(
                '    - `${permission['permission']}` — ${permission['risk']} risk; explicit approval required; not granted automatically${permission['blockedUntilReviewed'] == true ? '; blocked until reviewed' : ''}.',
              );
            }
          }
        }
        lines
          ..add('Source scripts and auxiliary files were preserved but **not executed**.')
          ..add('The Skills are registered and available for progressive disclosure. Use `extension_inspect` to read a selected Skill’s full instructions and only the referenced files needed for the task.');
        return lines.join('\n');
      },
    );
  }

  Future<String> _update(Map<String, dynamic> args, String? toolCallId) async {
    if (args['all'] == true) {
      return _runTracked(
        operation: 'update_all',
        kind: 'skill',
        target: 'all-remote-skills',
        source: 'all-supported-skill-sources',
        toolCallId: toolCallId,
        action: (cancelSignal, onProgress) async {
          final result = await skills.updateAllFromRegisteredSources(
            onProgress: onProgress,
            cancelSignal: cancelSignal,
          );
          final failureSummary = result.failed.entries
              .take(5)
              .map((entry) => '${entry.key}: ${entry.value}')
              .join('; ');
          return 'Updated ${result.updated.length} Skills. '
              '${result.failed.length} failed.'
              '${failureSummary.isEmpty ? '' : ' Failures: $failureSummary'}';
        },
      );
    }
    final id = _requiredString(args, 'id', max: 128);
    final requestedSource = (args['source'] ?? '').toString().trim();
    final registered = await registry.get('skill', id);
    final registeredSource = registered?.source.uri ?? '';
    final source = requestedSource.isNotEmpty
        ? requestedSource
        : registeredSource.isNotEmpty
            ? registeredSource
            : {'skills_sh', 'skillsSh'}.contains(registered?.source.type) &&
                    registered?.source.ref != null
                ? 'https://skills.sh/${registered!.source.ref}'
                : '';
    final isCatalogSource = _isSkillsShSource(source) &&
        (requestedSource.isNotEmpty || {'skills_sh', 'skillsSh'}.contains(registered?.source.type));
    final isGitHubSource = _isGitHubSource(source) &&
        (requestedSource.isNotEmpty || registered?.source.type == 'github');
    if (!isCatalogSource && !isGitHubSource) {
      throw StateError(
        'skill_update_source_missing: Skill "$id" has no valid registered '
        'GitHub or skills.sh origin. Open Skills, choose Connect update source, '
        'and attach the original repository or catalog URL before refreshing.',
      );
    }
    if (registered == null && requestedSource.isEmpty) {
      throw StateError('skill_not_registered');
    }

    SkillPack? containingPack;
    if (requestedSource.isEmpty) {
      final candidate = skills.skillPacks
          .where((pack) => pack.autoDetected && pack.skillIds.contains(id))
          .firstOrNull;
      if (candidate != null && skills.canUpdateSkillPack(candidate.id)) {
        containingPack = candidate;
      }
    }
    // Capture the nullable pack in a final local before the async callback.
    // Dart cannot promote the mutable outer local across an await boundary.
    final packToUpdate = containingPack;
    return _runTracked(
      operation: 'update',
      kind: 'skill',
      target: packToUpdate?.id ?? id,
      source: _safeHistorySource(source),
      toolCallId: toolCallId,
      action: (cancelSignal, onProgress) async {
        if (packToUpdate != null) {
          final updated = await skills.updateSkillPack(
            packToUpdate.id,
            onProgress: onProgress,
            cancelSignal: cancelSignal,
          );
          return 'Updated Skill Pack **${packToUpdate.name}** '
              '(`/${packToUpdate.shortcut}`): ${updated.length} member Skills '
              'from $source. Each member has its own rollback snapshot.';
        }
        final updated = requestedSource.isNotEmpty && isCatalogSource
            ? await skills.updateFromSkillsCatalog(
                id,
                catalogId: _skillsShId(source),
                onProgress: onProgress,
                cancelSignal: cancelSignal,
              )
            : requestedSource.isNotEmpty && isGitHubSource
                ? await skills.updateFromGitHub(
                    id,
                    source,
                    onProgress: onProgress,
                    cancelSignal: cancelSignal,
                  )
                : await skills.updateFromRegistered(
                    id,
                    onProgress: onProgress,
                    cancelSignal: cancelSignal,
                  );
        return 'Updated **${updated.name}** (`$id`) from $source. '
            'A rollback snapshot is available.';
      },
    );
  }

  Future<String> _toggle(
    Map<String, dynamic> args,
    bool enabled,
    String? toolCallId,
  ) async {
    final id = _requiredString(args, 'id', max: 128);
    return _runTracked(
      operation: enabled ? 'enable' : 'disable',
      kind: 'skill',
      target: id,
      toolCallId: toolCallId,
      action: (_, __) async {
        await skills.setEnabled(id, enabled);
        final skill = _findSkill(id);
        return '${enabled ? 'Enabled' : 'Disabled'} **${skill.name}** (`$id`).';
      },
    );
  }

  Future<String> _remove(Map<String, dynamic> args, String? toolCallId) async {
    final id = _requiredString(args, 'id', max: 128);
    final skill = _findSkill(id);
    return _runTracked(
      operation: 'remove',
      kind: 'skill',
      target: id,
      toolCallId: toolCallId,
      action: (_, __) async {
        await skills.delete(id);
        return 'Removed **${skill.name}** (`$id`) and its rollback snapshots.';
      },
    );
  }

  Future<String> _rollback(
    Map<String, dynamic> args,
    String? toolCallId,
  ) async {
    final id = _requiredString(args, 'id', max: 128);
    return _runTracked(
      operation: 'rollback',
      kind: 'skill',
      target: id,
      toolCallId: toolCallId,
      action: (_, __) async {
        final restored = await skills.rollback(id);
        return 'Restored the previous version of **${restored.name}** (`$id`).';
      },
    );
  }

  Future<String> _runTracked({
    required String operation,
    required String kind,
    required String target,
    String? source,
    String? toolCallId,
    required Future<String> Function(
      Future<void>? cancelSignal,
      void Function(SkillImportProgress progress) onProgress,
    )
    action,
  }) async {
    final rawRequestId = (toolCallId ?? '').replaceAll(
      RegExp(r'[^a-zA-Z0-9_.:-]'),
      '',
    );
    final requestId = rawRequestId.length > 40
        ? rawRequestId.substring(0, 40)
        : rawRequestId;
    final operationId =
        'ext-${DateTime.now().microsecondsSinceEpoch}'
        '${requestId.isEmpty ? '' : '-$requestId'}';
    await operations.start(
      id: operationId,
      operation: operation,
      kind: kind,
      target: target.length > 160 ? target.substring(0, 160) : target,
      source: source,
      requestId: requestId.isEmpty ? null : requestId,
    );
    ToolRun? liveRun;
    final liveToolCallId = toolCallId?.trim() ?? '';
    if (liveToolCallId.isNotEmpty && conversationId != null) {
      try {
        liveRun = toolRuns?.start(
          liveToolCallId,
          _toolName(operation),
          command: '$operation $target',
          conversationId: conversationId,
        );
        liveRun?.appendStdout(
          Uint8List.fromList(utf8.encode('Started $operation: $target\n')),
        );
      } catch (_) {
        // Live UI telemetry is optional; the operation remains tracked in the
        // durable extension-operation history if no registry is available.
      }
    }
    void emitProgressLine(String line) {
      try {
        liveRun?.appendStdout(Uint8List.fromList(utf8.encode('$line\n')));
      } catch (_) {
        // ToolRun telemetry must never fail the extension operation.
      }
    }

    final cancellation = ToolCallCancellation.current;
    final cancelCompleter = Completer<void>();
    final unregister = cancellation?.onCancel(() {
      if (!cancelCompleter.isCompleted) cancelCompleter.complete();
    });
    final cancelSignal = cancellation == null ? null : cancelCompleter.future;
    String? lastPhase;
    var lastBytes = 0;
    Future<void> progressTail = Future<void>.value();
    void onProgress(SkillImportProgress progress) {
      try {
        this.onProgress?.call(progress);
      } catch (_) {
        // Notification telemetry must not change the extension result.
      }
      final phase = progress.phase.name;
      final bytes = progress.receivedBytes;
      if (phase == lastPhase && bytes - lastBytes < 1024 * 1024) return;
      final phaseChanged = phase != lastPhase;
      lastPhase = phase;
      lastBytes = bytes;
      if (phaseChanged || bytes > 0) {
        final byteLabel =
            progress.totalBytes == null || progress.totalBytes! <= 0
            ? '$bytes bytes received'
            : '$bytes / ${progress.totalBytes} bytes';
        emitProgressLine('Skill ${phase.replaceAll('_', ' ')} · $byteLabel');
      }
      progressTail = progressTail.then((_) async {
        try {
          await operations.update(
            operationId,
            phase: phase,
            receivedBytes: bytes,
            totalBytes: progress.totalBytes,
          );
        } catch (_) {
          // Progress telemetry must not turn a successful installation into a
          // failed operation. The final status write is still attempted.
        }
      });
    }

    try {
      final result = await action(cancelSignal, onProgress);
      await progressTail;
      await operations.finish(
        operationId,
        status: ExtensionOperationStatus.succeeded,
        summary: result.length > 1000 ? result.substring(0, 1000) : result,
      );
      emitProgressLine('Completed successfully.');
      liveRun?.complete(
        status: ToolRunStatus.succeeded,
        retainUntilHandoff: true,
      );
      return '$result\n\nOperation ID: `$operationId`';
    } catch (error) {
      await progressTail;
      final cancelled =
          cancellation?.isCancelled() == true ||
          (error is HttpException &&
              error.message.toLowerCase().contains('abort')) ||
          error.toString().contains('RequestAbortedException');
      await operations.finish(
        operationId,
        status: cancelled
            ? ExtensionOperationStatus.cancelled
            : ExtensionOperationStatus.failed,
        errorCode: cancelled ? 'cancelled' : _errorCode(error),
      );
      emitProgressLine(
        cancelled
            ? 'Operation cancelled.'
            : 'Operation failed: ${_errorCode(error)} · ${_safeError(error).replaceAll(RegExp(r'[\r\n]+'), ' ')}',
      );
      liveRun?.complete(
        status: cancelled ? ToolRunStatus.cancelled : ToolRunStatus.failed,
        retainUntilHandoff: true,
      );
      rethrow;
    } finally {
      unregister?.call();
    }
  }

  static String _toolName(String operation) => switch (operation) {
    'install' => ExtensionCommandToolNames.install,
    'update' => ExtensionCommandToolNames.update,
    'enable' => ExtensionCommandToolNames.enable,
    'disable' => ExtensionCommandToolNames.disable,
    'remove' => ExtensionCommandToolNames.remove,
    'rollback' => ExtensionCommandToolNames.rollback,
    _ => ExtensionCommandToolNames.inspect,
  };

  Skill _findSkill(String id) {
    for (final skill in skills.skills) {
      if (skill.record.id == id) return skill;
    }
    throw StateError('Installed Skill not found: $id');
  }

  Future<String> _resolveLocalSource(
    String source,
    WorkspaceToolContext? workspaceContext,
  ) async {
    if (workspaceContext == null) {
      throw const FormatException(
        'Local Skill import needs a bound Kelivo workspace. Use a public '
        'GitHub URL or bind a workspace containing the local Skill folder/ZIP.',
      );
    }
    final resolved = await workspaceContext.paths.resolveReal(
      source,
      cwd: workspaceContext.cwd,
    );
    if (resolved.zone == WorkspaceZone.outside) {
      throw const FormatException(
        'Local source is outside the allowed workspace mounts.',
      );
    }
    return resolved.hostPath;
  }

  static bool _isGitHubSource(String source) {
    try {
      return GitHubSkillRef.tryParse(source) != null;
    } catch (_) {
      return false;
    }
  }

  static bool _isSkillsShSource(String source) {
    final text = source.contains('://') ? source : 'https://$source';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'skills.sh' ||
        uri.userInfo.isNotEmpty || (uri.hasPort && uri.port != 443) ||
        uri.hasQuery || uri.hasFragment) {
      return false;
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    return segments.length == 3 && segments.every((part) =>
        RegExp(r'^[A-Za-z0-9_.-]{1,100}$').hasMatch(part) &&
        part != '.' && part != '..');
  }

  static String _skillsShId(String source) {
    if (!_isSkillsShSource(source)) {
      throw const FormatException('invalid_skills_sh_skill_url');
    }
    final uri = Uri.parse(source.contains('://') ? source : 'https://$source');
    return uri.pathSegments.where((part) => part.isNotEmpty).join('/');
  }

  static String _safeHistorySource(String source) {
    if (_isGitHubSource(source)) {
      final normalized = source.contains('://') ? source : 'https://$source';
      final uri = Uri.parse(normalized);
      final ref = uri.queryParameters['ref'];
      return Uri(
        scheme: 'https',
        host: uri.host.toLowerCase(),
        path: uri.path,
        queryParameters: ref == null ? null : <String, String>{'ref': ref},
      ).toString();
    }
    if (_isSkillsShSource(source)) {
      final uri = Uri.parse(source.contains('://') ? source : 'https://$source');
      return Uri(scheme: 'https', host: 'skills.sh', path: uri.path).toString();
    }
    return 'local-source';
  }

  static String _requiredString(
    Map<String, dynamic> args,
    String key, {
    required int max,
  }) {
    final value = (args[key] ?? '').toString().trim();
    if (value.isEmpty || value.length > max) {
      throw FormatException('$key is required and must be <= $max characters.');
    }
    return value;
  }

  static String _errorCode(Object error) {
    if (error is FormatException) return 'invalid_input';
    if (error is HttpException) return 'network_error';
    if (error is FileSystemException) return 'filesystem_error';
    if (error is StateError) return 'state_error';
    return 'extension_operation_failed';
  }

  static String _safeError(Object error) {
    final message = error.toString();
    if (message.length <= 400) return message;
    return '${message.substring(0, 400)}…';
  }
}
