import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_models.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/app_directories.dart';

/// Workspace-scoped Runtime Profile controls. This page intentionally exposes
/// project profiles only; Skill/task profile ownership remains with their
/// respective provisioning flows.
class RuntimeProfilesPage extends StatefulWidget {
  const RuntimeProfilesPage({super.key});

  @override
  State<RuntimeProfilesPage> createState() => _RuntimeProfilesPageState();
}

class _RuntimeProfilesPageState extends State<RuntimeProfilesPage> {
  RuntimeProfileService? _service;
  Workspace? _workspace;
  List<RuntimeProfile> _profiles = const [];
  List<RuntimeProcessRecord> _running = const [];
  RuntimeStatus? _runtimeStatus;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({String? preferredWorkspaceId}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workspaces = context.read<WorkspaceProvider>();
      final runtimeProvider = context.read<WorkspaceRuntimeProvider>();
      await workspaces.loaded;
      await runtimeProvider.initialization;
      final store = context.read<ExtensionEntityStore>();
      _service ??= RuntimeProfileService(
        store: store,
        runtimeProvider: runtimeProvider,
      );
      await _service!.load();
      final candidates = workspaces.workspaces.toList()
        ..sort((a, b) {
          final at = a.lastUsedAt ?? a.updatedAt;
          final bt = b.lastUsedAt ?? b.updatedAt;
          return bt.compareTo(at);
        });
      final wanted = preferredWorkspaceId ?? _workspace?.id;
      final selected = candidates.where((w) => w.id == wanted).firstOrNull ??
          candidates.firstOrNull;
      RuntimeStatus? status;
      final runtime = runtimeProvider.runtime;
      if (runtime != null) status = await runtime.status();
      List<RuntimeProfile> profiles = const [];
      List<RuntimeProcessRecord> running = const [];
      if (selected != null) {
        profiles = await _service!.list(
          ownerId: selected.id,
          scope: RuntimeProfileScope.project,
        );
        running = _service!.processHistory(ownerId: selected.id)
            .where((record) => record.status == RuntimeProcessStatus.running)
            .toList(growable: false);
      }
      if (!mounted) return;
      setState(() {
        _workspace = selected;
        _profiles = profiles;
        _running = running;
        _runtimeStatus = status;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<WorkspaceToolContext> _buildContext(Workspace workspace) async {
    final provider = context.read<WorkspaceProvider>();
    final runtimeProvider = context.read<WorkspaceRuntimeProvider>();
    final runtime = runtimeProvider.runtime;
    final status = runtime == null ? null : await runtime.status();
    final hostRoot = await provider.hostRootFor(workspace);
    final session = await AppDirectories.sessionDir(
      'runtime-profile-ui-${workspace.id}',
    );
    final skills = await AppDirectories.getSkillsDirectory();
    final paths = status?.sandboxed == true
        ? WorkspacePaths.sandboxed(
            workspaceHostRoot: hostRoot,
            sessionHostDir: session.path,
            skillsHostDir: skills.path,
          )
        : WorkspacePaths.native(
            workspaceHostRoot: hostRoot,
            sessionHostDir: session.path,
            skillsHostDir: skills.path,
          );
    final outputs = Directory(p.join(session.path, 'outputs'));
    await outputs.create(recursive: true);
    return WorkspaceToolContext(
      workspace: workspace,
      binding: WorkspaceBinding(
        workspaceId: workspace.id,
        cwd: workspace.defaultCwd,
      ),
      paths: paths,
      sessionDir: session,
      outputsDir: outputs,
      runtimeStatus: status,
      runtimeRegistered: runtime != null,
    );
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy || _workspace == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      await _load(preferredWorkspaceId: _workspace?.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createProfile() async {
    final workspace = _workspace;
    final service = _service;
    if (workspace == null || service == null) return;
    final draft = await _showProfileDialog(context);
    if (draft == null || !mounted) return;
    await _perform(() async {
      final toolContext = await _buildContext(workspace);
      await service.create(
        name: draft.name,
        scope: RuntimeProfileScope.project,
        ownerId: workspace.id,
        ecosystems: draft.ecosystems,
        context: toolContext,
        limits: draft.limits,
        shareBaseTools: draft.shareBaseTools,
      );
    });
  }

  Future<void> _editProfile(RuntimeProfile profile) async {
    final workspace = _workspace;
    final service = _service;
    if (workspace == null || service == null) return;
    final draft = await _showProfileDialog(context, existing: profile);
    if (draft == null || !mounted) return;
    await _perform(() async {
      final toolContext = await _buildContext(workspace);
      await service.updateProjectSettings(
        profileId: profile.id,
        context: toolContext,
        name: draft.name,
        limits: draft.limits,
        shareBaseTools: draft.shareBaseTools,
      );
    });
  }

  Future<void> _setDefault(RuntimeProfile profile) async {
    final workspace = _workspace;
    final service = _service;
    if (workspace == null || service == null) return;
    await _perform(() async {
      await service.setDefault(
        profileId: profile.id,
        context: await _buildContext(workspace),
        workspaces: context.read<WorkspaceProvider>(),
      );
    });
  }

  Future<void> _clearDefault() async {
    final workspace = _workspace;
    final service = _service;
    if (workspace == null || service == null) return;
    await _perform(() async {
      await service.clearDefault(
        context: await _buildContext(workspace),
        workspaces: context.read<WorkspaceProvider>(),
      );
    });
  }

  Future<void> _removeProfile(RuntimeProfile profile) async {
    final workspace = _workspace;
    final service = _service;
    if (workspace == null || service == null) return;
    final l10n = AppLocalizations.of(context)!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.workspaceRuntimeRemove),
        content: Text(l10n.workspaceRuntimeRemoveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.workspaceRuntimeCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.workspaceRuntimeRemove),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await _perform(() async {
      final toolContext = await _buildContext(workspace);
      if (workspace.defaultRuntimeProfileId == profile.id) {
        await service.clearDefault(
          context: toolContext,
          workspaces: context.read<WorkspaceProvider>(),
        );
      }
      await service.remove(profileId: profile.id, context: toolContext);
    });
  }

  Future<void> _cancelRun(RuntimeProcessRecord record) async {
    final service = _service;
    if (service == null) return;
    await _perform(() async => service.cancelRun(record.runId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workspaceRuntimeProfilesTitle),
        actions: [
          IconButton(
            tooltip: l10n.workspaceFilesRefresh,
            onPressed: _loading || _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _workspace == null || _loading || _busy
          ? null
          : FloatingActionButton.extended(
              onPressed: _createProfile,
              icon: const Icon(Icons.add),
              label: Text(l10n.workspaceRuntimeCreate),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _workspace == null
              ? _ErrorView(message: _error!, onRetry: () => _load())
              : _workspace == null
                  ? Center(child: Text(l10n.workspaceRuntimeNoWorkspaces))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        DropdownButtonFormField<String>(
                          value: _workspace!.id,
                          decoration: InputDecoration(
                            labelText: l10n.workspaceRuntimeSelectWorkspace,
                            border: const OutlineInputBorder(),
                          ),
                          items: context.watch<WorkspaceProvider>().workspaces
                              .map((workspace) => DropdownMenuItem(
                                    value: workspace.id,
                                    child: Text(workspace.name),
                                  ))
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (id) {
                                  if (id != null) _load(preferredWorkspaceId: id);
                                },
                        ),
                        const SizedBox(height: 12),
                        if (_runtimeStatus?.ready != true)
                          _InfoCard(
                            icon: Icons.warning_amber_rounded,
                            child: Text(
                              _runtimeStatus?.reason ??
                                  l10n.workspaceRuntimeNoRuntime,
                            ),
                          ),
                        if (_error != null) ...[
                          _InfoCard(
                            icon: Icons.error_outline,
                            child: Text(_error!),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_running.isNotEmpty) ...[
                          Text(l10n.workspaceRuntimeRunning,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          for (final record in _running)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.timelapse),
                                title: Text(record.commandLabel),
                                subtitle: Text(record.runId),
                                trailing: TextButton(
                                  onPressed: _busy ? null : () => _cancelRun(record),
                                  child: Text(l10n.workspaceRuntimeCancelRun),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                        Text(l10n.workspaceRuntimeProfilesTitle,
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (_profiles.isEmpty)
                          _InfoCard(
                            icon: Icons.layers_outlined,
                            child: Text(l10n.workspaceRuntimeNoProfiles),
                          )
                        else
                          for (final profile in _profiles)
                            _ProfileCard(
                              profile: profile,
                              isDefault: profile.id ==
                                  _workspace!.defaultRuntimeProfileId,
                              busy: _busy,
                              onSetDefault: () => _setDefault(profile),
                              onClearDefault: _clearDefault,
                              onEdit: () => _editProfile(profile),
                              onRemove: () => _removeProfile(profile),
                            ),
                        const SizedBox(height: 16),
                        _InfoCard(
                          icon: Icons.inventory_2_outlined,
                          child: Text(l10n.workspaceRuntimeStorageScopeNote),
                        ),
                        _InfoCard(
                          icon: Icons.memory,
                          child: Text(l10n.workspaceRuntimePlatformLimitsNote),
                        ),
                        _InfoCard(
                          icon: Icons.thermostat,
                          child: Text(l10n.workspaceRuntimeThermalNote),
                        ),
                        _InfoCard(
                          icon: Icons.storage_outlined,
                          child: Text(l10n.workspaceRuntimeRootfsNote),
                        ),
                        _InfoCard(
                          icon: Icons.code_outlined,
                          child: Text(l10n.workspaceRuntimeInterpreterNote),
                        ),
                        _InfoCard(
                          icon: Icons.extension,
                          child: Text(l10n.workspaceRuntimeScopeNote),
                        ),
                        if (_busy) const LinearProgressIndicator(),
                      ],
                    ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isDefault,
    required this.busy,
    required this.onSetDefault,
    required this.onClearDefault,
    required this.onEdit,
    required this.onRemove,
  });

  final RuntimeProfile profile;
  final bool isDefault;
  final bool busy;
  final VoidCallback onSetDefault;
  final VoidCallback onClearDefault;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final limits = profile.limits.normalized();
    final ecosystems = profile.ecosystems.map((e) => switch (e) {
      RuntimeProfileEcosystem.shell => l10n.workspaceRuntimeShell,
      RuntimeProfileEcosystem.python => l10n.workspaceRuntimePython,
      RuntimeProfileEcosystem.node => l10n.workspaceRuntimeNode,
    }).join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(profile.name,
                      style: theme.textTheme.titleMedium),
                ),
                if (isDefault)
                  Chip(
                    label: Text(l10n.workspaceRuntimeDefault),
                    visualDensity: VisualDensity.compact,
                  ),
                PopupMenuButton<String>(
                  enabled: !busy,
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'remove') onRemove();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(l10n.workspaceRuntimeEdit)),
                    PopupMenuItem(value: 'remove', child: Text(l10n.workspaceRuntimeRemove)),
                  ],
                ),
              ],
            ),
            Text(ecosystems, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text('${l10n.workspaceRuntimeMaxDuration}: ${limits.maxDurationSeconds}s · '
                '${l10n.workspaceRuntimeMaxCpuSeconds}: ${limits.maxCpuSeconds}s'),
            Text('${l10n.workspaceRuntimeMaxConcurrentRuns}: ${limits.maxConcurrentRuns} · '
                '${l10n.workspaceRuntimeMaxProcesses}: ${limits.maxProcesses}'),
            Text('${l10n.workspaceRuntimeMemoryLimit}: ${limits.maxMemoryMegabytes} MB · '
                '${l10n.workspaceRuntimeTempLimit}: ${limits.maxTempMegabytes} MB'),
            Text('${l10n.workspaceRuntimeOutputLimit}: ${limits.maxOutputMegabytes} MB · '
                '${l10n.workspaceRuntimeFileLimit}: ${limits.maxFileMegabytes} MB'),
            const SizedBox(height: 10),
            Row(
              children: [
                if (!isDefault)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy || profile.status != RuntimeProfileStatus.ready
                          ? null
                          : onSetDefault,
                      child: Text(l10n.workspaceRuntimeSetDefault),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onClearDefault,
                      child: Text(l10n.workspaceRuntimeClearDefault),
                    ),
                  ),
              ],
            ),
            if (profile.lastError?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(profile.lastError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    )),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Expanded(child: child),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _ProfileDraft {
  const _ProfileDraft({
    required this.name,
    required this.ecosystems,
    required this.limits,
    required this.shareBaseTools,
  });
  final String name;
  final Set<RuntimeProfileEcosystem> ecosystems;
  final RuntimeResourceLimits limits;
  final bool shareBaseTools;
}

Future<_ProfileDraft?> _showProfileDialog(
  BuildContext context, {
  RuntimeProfile? existing,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: existing?.name ?? 'Project tools');
  final current = existing?.limits.normalized() ?? const RuntimeResourceLimits();
  final controllers = <String, TextEditingController>{
    'duration': TextEditingController(text: '${current.maxDurationSeconds}'),
    'cpu': TextEditingController(text: '${current.maxCpuSeconds}'),
    'concurrent': TextEditingController(text: '${current.maxConcurrentRuns}'),
    'processes': TextEditingController(text: '${current.maxProcesses}'),
    'memory': TextEditingController(text: '${current.maxMemoryMegabytes}'),
    'temp': TextEditingController(text: '${current.maxTempMegabytes}'),
    'output': TextEditingController(text: '${current.maxOutputMegabytes}'),
    'file': TextEditingController(text: '${current.maxFileMegabytes}'),
  };
  var ecosystems = Set<RuntimeProfileEcosystem>.from(
    existing?.ecosystems ?? {RuntimeProfileEcosystem.shell},
  );
  var shareBaseTools = existing?.shareBaseTools ?? true;
  try {
    return await showDialog<_ProfileDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null
              ? l10n.workspaceRuntimeCreate
              : l10n.workspaceRuntimeEdit),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: l10n.workspaceRuntimeProfileName,
                      ),
                      maxLength: 80,
                      validator: (value) => value == null || value.trim().isEmpty
                          ? l10n.workspaceRuntimeProfileName
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.workspaceRuntimeEcosystems,
                        style: Theme.of(context).textTheme.titleSmall),
                    for (final ecosystem in RuntimeProfileEcosystem.values)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: ecosystems.contains(ecosystem),
                        title: Text(switch (ecosystem) {
                          RuntimeProfileEcosystem.shell => l10n.workspaceRuntimeShell,
                          RuntimeProfileEcosystem.python => l10n.workspaceRuntimePython,
                          RuntimeProfileEcosystem.node => l10n.workspaceRuntimeNode,
                        }),
                        onChanged: existing != null
                            ? null
                            : (selected) => setDialogState(() {
                                  if (selected == true) {
                                    ecosystems.add(ecosystem);
                                  } else {
                                    ecosystems.remove(ecosystem);
                                  }
                                }),
                      ),
                    if (ecosystems.isEmpty)
                      Text(l10n.workspaceRuntimeAtLeastOneEcosystem,
                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const Divider(height: 24),
                    _LimitField(controller: controllers['duration']!, label: l10n.workspaceRuntimeMaxDuration),
                    _LimitField(controller: controllers['cpu']!, label: l10n.workspaceRuntimeMaxCpuSeconds),
                    _LimitField(controller: controllers['concurrent']!, label: l10n.workspaceRuntimeMaxConcurrentRuns),
                    _LimitField(controller: controllers['processes']!, label: l10n.workspaceRuntimeMaxProcesses),
                    _LimitField(controller: controllers['memory']!, label: l10n.workspaceRuntimeMemoryLimit),
                    _LimitField(controller: controllers['temp']!, label: l10n.workspaceRuntimeTempLimit),
                    _LimitField(controller: controllers['output']!, label: l10n.workspaceRuntimeOutputLimit),
                    _LimitField(controller: controllers['file']!, label: l10n.workspaceRuntimeFileLimit),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: shareBaseTools,
                      title: Text(l10n.workspaceRuntimeShareBaseTools),
                      onChanged: (value) => setDialogState(
                          () => shareBaseTools = value ?? false),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.workspaceRuntimeCancel),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate() || ecosystems.isEmpty) return;
                int read(String key) => int.parse(controllers[key]!.text.trim());
                Navigator.pop(
                  dialogContext,
                  _ProfileDraft(
                    name: name.text.trim(),
                    ecosystems: ecosystems,
                    shareBaseTools: shareBaseTools,
                    limits: RuntimeResourceLimits(
                      maxDurationSeconds: read('duration'),
                      maxCpuSeconds: read('cpu'),
                      maxConcurrentRuns: read('concurrent'),
                      maxProcesses: read('processes'),
                      maxMemoryMegabytes: read('memory'),
                      maxTempMegabytes: read('temp'),
                      maxOutputMegabytes: read('output'),
                      maxFileMegabytes: read('file'),
                    ).normalized(),
                  ),
                );
              },
              child: Text(l10n.workspaceRuntimeSave),
            ),
          ],
        ),
      ),
    );
  } finally {
    name.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

class _LimitField extends StatelessWidget {
  const _LimitField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          validator: (value) {
            final parsed = int.tryParse(value?.trim() ?? '');
            return parsed == null || parsed < 1 ? 'Enter a positive whole number' : null;
          },
        ),
      );
}
