import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/extension_record.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/extensions/extension_registry_repository.dart';
import 'package:Kelivo/core/services/video_providers/video_provider_credential_store.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';

/// Secure credential editor for installed declarative video-provider connectors.
/// Keys are entered directly into a password field and are never sent to chat.
class VideoProviderCredentialsPage extends StatefulWidget {
  const VideoProviderCredentialsPage({super.key});

  @override
  State<VideoProviderCredentialsPage> createState() =>
      _VideoProviderCredentialsPageState();
}

class _VideoProviderCredentialsPageState
    extends State<VideoProviderCredentialsPage> {
  late Future<List<_ProviderEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _load();
  }

  Future<List<_ProviderEntry>> _load() async {
    final registry = context.read<ExtensionRegistryRepository>();
    final workspaces = context.read<WorkspaceProvider>();
    await workspaces.loaded;
    final records = await registry.list(kind: 'video_provider');
    final entries = <_ProviderEntry>[];
    for (final record in records) {
      final workspaceId = record.metadata['workspaceId'];
      final providerId = record.metadata['providerId'];
      if (workspaceId is! String) continue;
      if (providerId is! String || providerId.isEmpty) continue;
      final workspace = workspaces.byId(workspaceId);
      if (workspace == null) continue;
      entries.add(_ProviderEntry(record: record, workspace: workspace));
    }
    entries.sort((a, b) {
      final workspaceSort = a.workspace.name.compareTo(b.workspace.name);
      return workspaceSort != 0
          ? workspaceSort
          : a.record.name.toLowerCase().compareTo(b.record.name.toLowerCase());
    });
    return entries;
  }

  void _reload() => setState(() => _entries = _load());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.directionalBack(context)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('AI video provider keys'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Lucide.RefreshCw),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<_ProviderEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load installed connectors.'));
          }
          final entries = snapshot.data ?? const <_ProviderEntry>[];
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Lucide.KeyRound, size: 34, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    const Text('No video-provider connectors installed.'),
                    const SizedBox(height: 6),
                    Text(
                      'Install a provider connector with the video_provider conversation tool, then return here to configure its API key.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _ProviderCredentialCard(
              key: ValueKey('${entries[index].workspace.id}:${entries[index].record.id}'),
              entry: entries[index],
            ),
          );
        },
      ),
    );
  }
}

final class _ProviderEntry {
  const _ProviderEntry({required this.record, required this.workspace});

  final ExtensionRecord record;
  final Workspace workspace;

  String get providerId => record.metadata['providerId']! as String;
}

class _ProviderCredentialCard extends StatefulWidget {
  const _ProviderCredentialCard({super.key, required this.entry});

  final _ProviderEntry entry;

  @override
  State<_ProviderCredentialCard> createState() =>
      _ProviderCredentialCardState();
}

class _ProviderCredentialCardState extends State<_ProviderCredentialCard> {
  final _controller = TextEditingController();
  final _store = SecureVideoProviderCredentialStore();
  bool _loading = true;
  bool _configured = false;
  bool _credentialLoadFailed = false;
  bool _saving = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    var configured = false;
    var failed = false;
    try {
      configured = await _store.has(
        workspaceId: widget.entry.workspace.id,
        providerId: widget.entry.providerId,
      );
    } on Object {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _configured = configured;
      _credentialLoadFailed = failed;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _store.write(
        workspaceId: widget.entry.workspace.id,
        providerId: widget.entry.providerId,
        apiKey: key,
      );
      _controller.clear();
      if (!mounted) return;
      setState(() {
        _configured = true;
        _credentialLoadFailed = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key stored securely on this device.')),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not store this API key.')),
      );
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    try {
      await _store.clear(
        workspaceId: widget.entry.workspace.id,
        providerId: widget.entry.providerId,
      );
      if (!mounted) return;
      setState(() {
        _configured = false;
        _credentialLoadFailed = false;
        _saving = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final record = widget.entry.record;
    final workspace = widget.entry.workspace;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Lucide.KeyRound, color: cs.primary),
        title: Text(record.name),
        subtitle: Text(
          '${workspace.name} · ${record.version ?? 'unknown version'} · ${_loading ? 'Checking key…' : _credentialLoadFailed ? 'Key status unavailable' : _configured ? 'API key configured' : 'API key not configured'}',
        ),
        initiallyExpanded: _expanded,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextField(
            controller: _controller,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'API key',
              hintText: 'Enter a key provided by the service',
              helperText: _credentialLoadFailed
                  ? 'Key status could not be read. Saving a new key will replace the stored value.'
                  : 'Stored in Android secure storage. The key is not sent to the AI model or included in chat history.',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving || _controller.text.trim().isEmpty ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Lucide.Check, size: 17),
                  label: const Text('Save key'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _saving || !_configured ? null : _clear,
                icon: const Icon(Lucide.Trash2, size: 17),
                label: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
