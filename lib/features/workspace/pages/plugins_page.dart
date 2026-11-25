import 'dart:io';

import 'package:Kelivo/core/models/extension_record.dart';
import 'package:Kelivo/core/models/plugin_component.dart';
import 'package:Kelivo/core/services/extensions/extension_registry_repository.dart';
import 'package:Kelivo/core/services/extensions/plugin_manifest_service.dart';
import 'package:Kelivo/shared/utils/file_picker_compat.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Read-only inventory and lifecycle controls for installed Plugin bundles.
/// Components are displayed as descriptors only; this page has no executor.
class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key});

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  PluginManifestService? _service;
  Future<List<ExtensionRecord>>? _plugins;
  bool _busy = false;

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode == 'ar';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= PluginManifestService(
      registry: context.read<ExtensionRegistryRepository>(),
    );
    _plugins ??= _service!.listPlugins();
  }

  void _reload() {
    setState(() => _plugins = _service!.listPlugins());
  }

  Future<void> _importDirectory() async {
    String? directoryPath;
    try {
      directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: _isArabic ? 'اختر مجلد Plugin' : 'Select Plugin directory',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'اختيار المجلد غير مدعوم في هذا النظام؛ استورد ZIP بدلاً منه.'
                : 'Folder selection is unavailable on this platform; import a ZIP instead.',
          ),
        ),
      );
      return;
    }
    if (directoryPath == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final record = await _service!.installDirectory(
        sourceDirectory: Directory(directoryPath),
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'تم تثبيت Plugin كبيانات وصفية: ' + record.name
                : 'Plugin installed as metadata: ' + record.name,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (_isArabic ? 'تعذر تثبيت Plugin: ' : 'Plugin install failed: ') +
                error.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importArchive() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      dialogTitle: _isArabic ? 'اختر أرشيف Plugin' : 'Select Plugin ZIP',
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final selected = result.files.first;
    if (selected.size > 200 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'حجم أرشيف Plugin يتجاوز الحد المسموح'
                : 'Plugin ZIP exceeds the allowed size',
          ),
        ),
      );
      return;
    }

    Directory? temporaryDirectory;
    setState(() => _busy = true);
    try {
      final selectedPath = selected.path;
      late final File archiveFile;
      if (selectedPath != null &&
          selectedPath.isNotEmpty &&
          await File(selectedPath).exists()) {
        archiveFile = File(selectedPath);
      } else {
        temporaryDirectory = await Directory.systemTemp.createTemp(
          'kelivo-plugin-picker-',
        );
        archiveFile = File(
          '${temporaryDirectory.path}/selected-plugin.zip',
        );
        await archiveFile.writeAsBytes(
          await selected.readAsBytes(),
          flush: true,
        );
      }
      final record = await _service!.installArchive(
        archiveFile: archiveFile,
        source: const ExtensionSource(type: 'local'),
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (_isArabic ? 'تم استيراد Plugin: ' : 'Imported Plugin: ') +
                record.name,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (_isArabic ? 'تعذر استيراد Plugin: ' : 'Plugin import failed: ') +
                error.toString(),
          ),
        ),
      );
    } finally {
      final tempDirectory = temporaryDirectory;
      if (tempDirectory != null && await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uninstall(ExtensionRecord plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_isArabic ? 'إزالة Plugin؟' : 'Remove Plugin?'),
        content: Text(
          _isArabic
              ? 'سيتم إزالة الحزمة ومكوناتها المحفوظة: ' + plugin.name
              : 'This removes the saved bundle and its component descriptors: ' +
                  plugin.name,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_isArabic ? 'إزالة' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service!.uninstallPlugin(plugin.id);
      if (!mounted) return;
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (_isArabic ? 'تعذرت الإزالة: ' : 'Removal failed: ') +
                error.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<PluginComponentDescriptor> _components(ExtensionRecord plugin) {
    final raw = plugin.metadata['components'];
    if (raw is! List) return const <PluginComponentDescriptor>[];
    try {
      return [
        for (final item in raw) PluginComponentDescriptor.fromJson(item),
      ];
    } catch (_) {
      return const <PluginComponentDescriptor>[];
    }
  }

  String _statusLabel(String status) {
    if (!_isArabic) {
      switch (status) {
        case 'disabled_by_default':
          return 'Disabled by default';
        case 'unsupported':
          return 'Unsupported';
        default:
          return 'Inspect only';
      }
    }
    switch (status) {
      case 'disabled_by_default':
        return 'معطّل افتراضياً';
      case 'unsupported':
        return 'غير مدعوم';
      default:
        return 'للفحص فقط';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pluginsFuture = _plugins;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isArabic ? 'إدارة Plugins' : 'Plugins'),
        actions: [
          IconButton(
            tooltip: _isArabic ? 'تحديث' : 'Refresh',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'plugins-import-zip',
            tooltip: _isArabic ? 'استيراد ZIP' : 'Import ZIP',
            onPressed: _busy ? null : _importArchive,
            child: const Icon(Icons.archive_outlined),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'plugins-import-folder',
            onPressed: _busy ? null : _importDirectory,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.create_new_folder_outlined),
            label: Text(_isArabic ? 'استيراد مجلد' : 'Import folder'),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isArabic
                          ? 'الفحص والتثبيت يحفظان المكونات كبيانات وصفية فقط. لن يتم تشغيل Commands أو Hooks أو Scripts أو خوادم MCP تلقائياً.'
                          : 'Inspection and installation store metadata only. Commands, Hooks, Scripts, and MCP servers are never started automatically.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: pluginsFuture == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<List<ExtensionRecord>>(
                    future: pluginsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(snapshot.error.toString()),
                        );
                      }
                      final plugins = snapshot.data ?? const [];
                      if (plugins.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              _isArabic
                                  ? 'لا توجد Plugins مثبتة. استورد مجلد Plugin يحتوي على .claude-plugin/plugin.json.'
                                  : 'No Plugins installed. Import a directory containing .claude-plugin/plugin.json.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        itemCount: plugins.length,
                        itemBuilder: (context, index) {
                          final plugin = plugins[index];
                          final components = _components(plugin);
                          final warnings = plugin.metadata['warnings'];
                          return Card(
                            child: ExpansionTile(
                              leading: const Icon(Icons.extension_outlined),
                              title: Text(plugin.name),
                              subtitle: Text(
                                [
                                  if (plugin.version != null)
                                    'v' + plugin.version!,
                                  plugin.status.name,
                                  components.length.toString() +
                                      (_isArabic
                                          ? ' مكونات'
                                          : ' components'),
                                ].join(' · '),
                              ),
                              children: [
                                for (final component in components)
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.description_outlined,
                                    ),
                                    title: Text(component.name),
                                    subtitle: Text(
                                      component.kind +
                                          ' · ' +
                                          component.relativePath +
                                          '\n' +
                                          _statusLabel(component.status),
                                    ),
                                    isThreeLine: true,
                                  ),
                                if (warnings is List && warnings.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      (_isArabic
                                              ? 'تحذيرات manifest: '
                                              : 'Manifest warnings: ') +
                                          warnings.join('\n'),
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _uninstall(plugin),
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(
                                      _isArabic ? 'إزالة' : 'Uninstall',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
