import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';
import '../../models/extension_record.dart';
import '../../models/plugin_component.dart';
import '../../models/plugin_manifest.dart';
import 'extension_registry_repository.dart';

const int _maxPluginFiles = 4096;
const int _maxPluginEntries = 8192;
const int _maxPluginBytes = 200 * 1024 * 1024;
const int _maxPluginFileBytes = 32 * 1024 * 1024;
const int _maxPluginManifestBytes = 64 * 1024;
const int _maxPluginComponents = 128;

final RegExp _sensitiveManifestKey = RegExp(
  r'(api[_-]?key|access[_-]?token|refresh[_-]?token|token|credential|password|secret|private[_-]?key|authorization|\bauth\b)',
  caseSensitive: false,
);

final class PluginManifestInspection {
  const PluginManifestInspection._({
    required this.manifest,
    required this.components,
    required this.warnings,
    required this.errors,
    required this.sourceDigest,
    required this.fileCount,
    required this.totalBytes,
    required _PluginInventory inventory,
  }) : _inventory = inventory;

  final PluginManifest manifest;
  final List<PluginComponentDescriptor> components;
  final List<String> warnings;
  final List<String> errors;
  final String sourceDigest;
  final int fileCount;
  final int totalBytes;
  final _PluginInventory _inventory;

  bool get canInstall => errors.isEmpty;
}

final class _PluginFile {
  const _PluginFile({
    required this.file,
    required this.sizeBytes,
    required this.digest,
  });

  final File file;
  final int sizeBytes;
  final String digest;
}

final class _PluginInventory {
  const _PluginInventory({
    required this.files,
    required this.directories,
    required this.digest,
    required this.totalBytes,
  });

  final Map<String, _PluginFile> files;
  final Set<String> directories;
  final String digest;
  final int totalBytes;
}

/// Reads and installs Claude-compatible Plugin directories without executing
/// any declared command, hook, script, agent, or MCP server.
final class PluginManifestService {
  PluginManifestService({
    required ExtensionRegistryRepository registry,
    Directory? pluginsRoot,
    Future<void> Function(ExtensionRecord record)? beforeRegistryWrite,
  }) : _registry = registry,
       _pluginsRoot = pluginsRoot,
       _beforeRegistryWrite = beforeRegistryWrite;

  final ExtensionRegistryRepository _registry;
  final Directory? _pluginsRoot;
  final Future<void> Function(ExtensionRecord record)? _beforeRegistryWrite;

  Future<Directory> _root() async =>
      _pluginsRoot ?? await AppDirectories.getPluginsDirectory();

  Future<List<ExtensionRecord>> listPlugins() =>
      _registry.list(kind: 'plugin');

  /// Read-only inspection. No files are changed and no plugin component runs.
  Future<PluginManifestInspection> inspectDirectory(Directory root) async {
    final inventory = await _buildInventory(root);
    const manifestPath = '.claude-plugin/plugin.json';
    final manifestFile = inventory.files[manifestPath];
    if (manifestFile == null) {
      throw const FormatException('plugin_manifest_not_found');
    }
    if (manifestFile.sizeBytes > _maxPluginManifestBytes) {
      throw const FormatException('plugin_manifest_too_large');
    }

    final decoded = jsonDecode(await manifestFile.file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('plugin_manifest_json_object_required');
    }
    final manifest = PluginManifest.fromJson(
      Map<String, Object?>.from(decoded),
    );

    final warnings = <String>[...manifest.warnings];
    final errors = <String>[];
    final components = <PluginComponentDescriptor>[];
    final names = <String>{};

    Future<void> addPathGroup({
      required String kind,
      required List<String> declaredPaths,
      required String defaultPath,
      required String status,
      required bool markdownOnly,
      bool explicitPaths = false,
    }) async {
      final paths = declaredPaths.isEmpty
          ? <String>[defaultPath]
          : declaredPaths;
      for (final rawPath in paths) {
        late final String relative;
        try {
          relative = _normalizeDeclaredPath(rawPath);
        } on FormatException {
          errors.add('unsafe_component_path:' + kind);
          continue;
        }
        final exists = inventory.files.containsKey(relative) ||
            inventory.directories.contains(relative) ||
            inventory.files.keys.any((path) => path.startsWith(relative + '/'));
        if (!exists) {
          if (explicitPaths && declaredPaths.isNotEmpty) {
            errors.add('missing_component_path:' + kind + ':' + relative);
          }
          continue;
        }

        final candidates = inventory.files.keys
            .where(
              (path) =>
                  path == relative || path.startsWith(relative + '/'),
            )
            .toList()
          ..sort();

        if (kind == 'skill') {
          final skillFiles = candidates
              .where((path) => p.posix.basename(path) == 'SKILL.md')
              .toList();
          if (skillFiles.isEmpty) {
            if (explicitPaths && declaredPaths.isNotEmpty) {
              errors.add('skill_manifest_missing:' + relative);
            }
            continue;
          }
          for (final path in skillFiles) {
            final item = inventory.files[path]!;
            final name = p.posix.basename(p.posix.dirname(path));
            if (name.length > 160) {
              errors.add('plugin_component_name_too_long:skill');
              continue;
            }
            final identity = 'skill:' + name.toLowerCase();
            if (!names.add(identity)) {
              errors.add('duplicate_component_name:' + identity);
            }
            if (components.length >= _maxPluginComponents) {
              errors.add('plugin_component_limit');
              return;
            }
            components.add(
              PluginComponentDescriptor(
                kind: kind,
                name: name,
                relativePath: path,
                status: status,
                digest: 'sha256:' + item.digest,
                sizeBytes: item.sizeBytes,
              ),
            );
          }
          continue;
        }

        for (final path in candidates) {
          final item = inventory.files[path]!;
          final isMarkdown = p.posix.extension(path).toLowerCase() == '.md';
          final componentStatus = markdownOnly && !isMarkdown
              ? 'unsupported'
              : status;
          final name = p.posix.basenameWithoutExtension(path);
          if (name.length > 160) {
            errors.add('plugin_component_name_too_long:' + kind);
            continue;
          }
          final identity = kind + ':' + name.toLowerCase();
          if (!names.add(identity)) {
            errors.add('duplicate_component_name:' + identity);
          }
          if (components.length >= _maxPluginComponents) {
            errors.add('plugin_component_limit');
            return;
          }
          components.add(
            PluginComponentDescriptor(
              kind: kind,
              name: name,
              relativePath: path,
              status: componentStatus,
              digest: 'sha256:' + item.digest,
              sizeBytes: item.sizeBytes,
            ),
          );
        }
      }
    }

    await addPathGroup(
      kind: 'command',
      declaredPaths: manifest.commandPaths,
      defaultPath: 'commands',
      status: 'inspect_only',
      markdownOnly: true,
      explicitPaths: true,
    );
    await addPathGroup(
      kind: 'agent',
      declaredPaths: manifest.agentPaths,
      defaultPath: 'agents',
      status: 'inspect_only',
      markdownOnly: true,
      explicitPaths: true,
    );
    await addPathGroup(
      kind: 'skill',
      declaredPaths: manifest.skillPaths,
      defaultPath: 'skills',
      status: 'inspect_only',
      markdownOnly: true,
      explicitPaths: true,
    );

    final hookPaths = manifest.hookPaths.isNotEmpty
        ? manifest.hookPaths
        : inventory.files.containsKey('hooks/hooks.json')
        ? const <String>['hooks/hooks.json']
        : const <String>[];
    await addPathGroup(
      kind: 'hook',
      declaredPaths: hookPaths,
      defaultPath: 'hooks/hooks.json',
      status: 'disabled_by_default',
      markdownOnly: false,
      explicitPaths: true,
    );

    if (inventory.files.containsKey('.mcp.json')) {
      final mcpFile = inventory.files['.mcp.json']!;
      if (components.length >= _maxPluginComponents) {
        errors.add('plugin_component_limit');
      } else {
      try {
        final mcpValue = jsonDecode(await mcpFile.file.readAsString());
        if (mcpValue is! Map) {
          warnings.add('mcp_manifest_not_object');
        }
      } catch (_) {
        warnings.add('mcp_manifest_invalid_json');
      }
      components.add(
        PluginComponentDescriptor(
          kind: 'mcp_server',
          name: 'MCP configuration',
          relativePath: '.mcp.json',
          status: 'disabled_by_default',
          digest: 'sha256:' + mcpFile.digest,
          sizeBytes: mcpFile.sizeBytes,
        ),
      );
      }
    }

    await addPathGroup(
      kind: 'script',
      declaredPaths: const <String>[],
      defaultPath: 'scripts',
      status: 'unsupported',
      markdownOnly: false,
    );

    for (final path in manifest.outputStylePaths) {
      late final String relative;
      try {
        relative = _normalizeDeclaredPath(path);
      } on FormatException {
        errors.add('unsafe_component_path:output_style');
        continue;
      }
      final item = inventory.files[relative];
      if (item == null) {
        errors.add('missing_component_path:output_style:' + relative);
        continue;
      }
      final name = p.posix.basenameWithoutExtension(relative);
      final identity = 'output_style:' + name.toLowerCase();
      if (!names.add(identity)) {
        errors.add('duplicate_component_name:' + identity);
      }
      if (components.length >= _maxPluginComponents) {
        errors.add('plugin_component_limit');
        break;
      }
      if (name.length > 160) {
        errors.add('plugin_component_name_too_long:output_style');
        continue;
      }
      components.add(
        PluginComponentDescriptor(
          kind: 'output_style',
          name: name,
          relativePath: relative,
          status: 'unsupported',
          digest: 'sha256:' + item.digest,
          sizeBytes: item.sizeBytes,
        ),
      );
    }

    components.sort((a, b) {
      final kindOrder = a.kind.compareTo(b.kind);
      if (kindOrder != 0) return kindOrder;
      final nameOrder = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return nameOrder != 0
          ? nameOrder
          : a.relativePath.compareTo(b.relativePath);
    });

    return PluginManifestInspection._(
      manifest: manifest,
      components: List<PluginComponentDescriptor>.unmodifiable(components),
      warnings: List<String>.unmodifiable(warnings.toSet().toList()..sort()),
      errors: List<String>.unmodifiable(errors.toSet().toList()..sort()),
      sourceDigest: inventory.digest,
      fileCount: inventory.files.length,
      totalBytes: inventory.totalBytes,
      inventory: inventory,
    );
  }

  /// Installs or updates a Plugin directory using filesystem staging and
  /// compensating rollback around the single parent-registry row.
  ///
  /// Components remain descriptors only. This method never invokes a child
  /// process, Hook, MCP server, command, or script.
  Future<ExtensionRecord> installDirectory({
    required Directory sourceDirectory,
    ExtensionSource? source,
  }) async {
    final sourceInspection = await inspectDirectory(sourceDirectory);
    if (!sourceInspection.canInstall) {
      throw FormatException(
        'plugin_manifest_invalid:' + sourceInspection.errors.join(','),
      );
    }

    final root = await _root();
    await root.create(recursive: true);
    final rootType = await FileSystemEntity.type(
      root.path,
      followLinks: false,
    );
    if (rootType != FileSystemEntityType.directory) {
      throw const FormatException('plugin_storage_root_not_directory');
    }
    final canonicalRoot = p.canonicalize(root.path);
    final canonicalSource = p.canonicalize(sourceDirectory.path);
    if (p.equals(canonicalRoot, canonicalSource) ||
        p.isWithin(canonicalRoot, canonicalSource) ||
        p.isWithin(canonicalSource, canonicalRoot)) {
      throw const FormatException('plugin_source_overlaps_storage_root');
    }

    final id = pluginIdForName(sourceInspection.manifest.name);
    final previous = await _registry.get('plugin', id);
    final destination = Directory(p.join(root.path, id));
    final destinationType = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    final destinationExists = destinationType != FileSystemEntityType.notFound;
    if (destinationType == FileSystemEntityType.link ||
        (destinationExists &&
            destinationType != FileSystemEntityType.directory)) {
      throw const FormatException('plugin_destination_unsafe');
    }
    if (destinationExists && previous == null) {
      throw const FormatException('plugin_destination_unregistered');
    }
    if (!destinationExists && previous != null) {
      throw const FormatException('plugin_directory_missing');
    }
    if (previous != null &&
        previous.name.toLowerCase() !=
            sourceInspection.manifest.name.toLowerCase()) {
      throw const FormatException('plugin_id_collision');
    }

    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final stage = Directory(p.join(root.path, '.stage-' + id + '-' + suffix));
    final backup = Directory(
      p.join(root.path, '.backup-' + id + '-' + suffix),
    );
    var backupMoved = false;
    var newDestinationInstalled = false;
    try {
      await stage.create(recursive: false);
      await _copyInventory(sourceInspection._inventory, stage);
      final stagedInspection = await inspectDirectory(stage);
      if (!stagedInspection.canInstall ||
          stagedInspection.sourceDigest != sourceInspection.sourceDigest) {
        throw const FormatException('plugin_source_changed_during_copy');
      }

      try {
        if (destinationExists) {
          await destination.rename(backup.path);
          backupMoved = true;
        }
        await stage.rename(destination.path);
        newDestinationInstalled = true;

        final now = DateTime.now().toUtc();
        final record = _recordFromInspection(
          id: id,
          inspection: stagedInspection,
          source: source ?? previous?.source ?? const ExtensionSource(type: 'local'),
          installedAt: previous?.installedAt ?? now,
          updatedAt: now,
        );
        await _beforeRegistryWrite?.call(record);
        await _registry.upsert(record);
        if (backupMoved) {
          try {
            await backup.delete(recursive: true);
          } catch (_) {
            // The committed Plugin remains valid; a stale backup is harmless.
          }
        }
        return record;
      } catch (error, stackTrace) {
        try {
          final installedType = await FileSystemEntity.type(
            destination.path,
            followLinks: false,
          );
          if (newDestinationInstalled &&
              installedType == FileSystemEntityType.directory) {
            await destination.delete(recursive: true);
          }
          if (backupMoved) {
            await backup.rename(destination.path);
            backupMoved = false;
          }
          if (previous == null) {
            await _registry.remove('plugin', id);
          } else {
            await _registry.upsert(previous);
          }
        } catch (_) {
          Error.throwWithStackTrace(
            StateError('plugin_install_rollback_incomplete'),
            stackTrace,
          );
        }
        Error.throwWithStackTrace(error, stackTrace);
      }

    } finally {
      final stageType = await FileSystemEntity.type(
        stage.path,
        followLinks: false,
      );
      if (stageType == FileSystemEntityType.directory) {
        await stage.delete(recursive: true);
      }
    }
  }

  /// Safely extracts a Plugin ZIP into a temporary directory and imports it.
  /// ZIP symlinks, traversal paths, duplicate entries and oversized archives
  /// are rejected before any Plugin files reach persistent storage.
  Future<ExtensionRecord> installArchive({
    required File archiveFile,
    ExtensionSource? source,
  }) async {
    final archiveType = await FileSystemEntity.type(
      archiveFile.path,
      followLinks: false,
    );
    if (archiveType != FileSystemEntityType.file) {
      throw const FormatException('plugin_archive_not_regular_file');
    }
    if (await archiveFile.length() > _maxPluginBytes) {
      throw const FormatException('plugin_archive_size_limit');
    }

    final temporary = await Directory.systemTemp.createTemp(
      'kelivo-plugin-archive-',
    );
    final extracted = Directory(p.join(temporary.path, 'plugin'));
    final input = InputFileStream(archiveFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final entries = <String, ArchiveFile>{};
      var entryCount = 0;
      var declaredBytes = 0;

      for (final entry in archive) {
        entryCount++;
        if (entryCount > 8192) {
          throw const FormatException('plugin_archive_entry_limit');
        }
        if (entry.isSymbolicLink) {
          throw const FormatException('plugin_archive_symlink_not_allowed');
        }
        if (!entry.isFile) {
          _normalizePluginArchivePath(entry.name);
          continue;
        }
        final relative = _normalizePluginArchivePath(entry.name);
        if (relative == null) continue;
        if (entries.containsKey(relative)) {
          throw FormatException('plugin_archive_duplicate_entry:' + relative);
        }
        if (entry.size < 0 || entry.size > _maxPluginFileBytes) {
          throw const FormatException('plugin_archive_file_size_limit');
        }
        declaredBytes += entry.size;
        if (declaredBytes > _maxPluginBytes) {
          throw const FormatException('plugin_archive_expanded_size_limit');
        }
        entries[relative] = entry;
      }
      if (entries.isEmpty) {
        throw const FormatException('plugin_archive_empty');
      }

      var prefix = '';
      if (!entries.containsKey('.claude-plugin/plugin.json')) {
        final roots = entries.keys.map((path) => path.split('/').first).toSet();
        if (roots.length == 1) {
          final candidate = roots.single + '/.claude-plugin/plugin.json';
          if (entries.containsKey(candidate)) prefix = roots.single;
        }
      }
      final manifestPath = prefix.isEmpty
          ? '.claude-plugin/plugin.json'
          : prefix + '/.claude-plugin/plugin.json';
      if (!entries.containsKey(manifestPath)) {
        throw const FormatException('plugin_manifest_not_found_in_archive');
      }

      await extracted.create(recursive: true);
      final canonicalRoot = p.canonicalize(extracted.path);
      var actualBytes = 0;
      final sortedPaths = entries.keys.toList()..sort();
      for (final archivePath in sortedPaths) {
        final relative = prefix.isEmpty
            ? archivePath
            : archivePath.substring(prefix.length + 1);
        _validateFilesystemRelativePath(relative);
        final destination = p.join(extracted.path, relative);
        final canonicalDestination = p.canonicalize(destination);
        if (!p.equals(canonicalRoot, canonicalDestination) &&
            !p.isWithin(canonicalRoot, canonicalDestination)) {
          throw const FormatException('plugin_archive_path_escape');
        }
        await Directory(p.dirname(destination)).create(recursive: true);
        final output = _LimitedPluginOutputStream(
          destination,
          _maxPluginBytes - actualBytes,
        );
        try {
          entries[archivePath]!.writeContent(output);
          actualBytes += output.length;
        } finally {
          output.closeSync();
        }
        if (actualBytes > _maxPluginBytes) {
          throw const FormatException('plugin_archive_expanded_size_limit');
        }
      }
      return await installDirectory(
        sourceDirectory: extracted,
        source: source ?? const ExtensionSource(type: 'local'),
      );
    } finally {
      input.closeSync();
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    }
  }

  /// Removes the parent Plugin only after moving its files to a reversible
  /// backup. If the registry delete fails, the original directory is restored.
  Future<void> uninstallPlugin(String id) async {
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$').hasMatch(id)) {
      throw const FormatException('plugin_id');
    }
    final existing = await _registry.get('plugin', id);
    if (existing == null) return;

    final root = await _root();
    final destination = Directory(p.join(root.path, id));
    final type = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw const FormatException('plugin_destination_unsafe');
    }
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw const FormatException('plugin_destination_unsafe');
    }

    final backup = Directory(
      p.join(
        root.path,
        '.uninstall-' + id + '-' +
            DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    var moved = false;
    if (type == FileSystemEntityType.directory) {
      await destination.rename(backup.path);
      moved = true;
    }
    try {
      await _registry.remove('plugin', id);
    } catch (error, stackTrace) {
      if (moved) {
        try {
          await backup.rename(destination.path);
        } catch (_) {
          Error.throwWithStackTrace(
            StateError('plugin_uninstall_rollback_incomplete'),
            stackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (moved) {
      await backup.delete(recursive: true);
    }
  }

  static String pluginIdForName(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isNotEmpty) return slug.length > 128 ? slug.substring(0, 128) : slug;
    return 'plugin-' +
        sha256.convert(utf8.encode(name)).toString().substring(0, 16);
  }

  ExtensionRecord _recordFromInspection({
    required String id,
    required PluginManifestInspection inspection,
    required ExtensionSource source,
    required DateTime installedAt,
    required DateTime updatedAt,
  }) {
    final warnings = <String>[...inspection.warnings];
    final safeUnknownFields = _sanitizeMetadata(
      inspection.manifest.unknownFields,
      warnings,
      'unknownFields',
    );
    final safeAuthor = _sanitizeMetadata(
      inspection.manifest.author,
      warnings,
      'author',
    );
    final homepage = _safePublicUrl(inspection.manifest.homepage);
    final repository = _safePublicUrl(inspection.manifest.repository);
    final metadata = <String, Object?>{
      'pluginSchemaVersion': PluginManifest.schemaVersion,
      'manifestFormat': 'claude-plugin',
      if (inspection.manifest.description != null)
        'description': inspection.manifest.description,
      if (safeAuthor != null) 'author': safeAuthor,
      if (homepage != null) 'homepage': homepage,
      if (repository != null) 'repository': repository,
      if (inspection.manifest.license != null)
        'license': inspection.manifest.license,
      if (inspection.manifest.keywords.isNotEmpty)
        'keywords': inspection.manifest.keywords,
      if (safeUnknownFields is Map && safeUnknownFields.isNotEmpty)
        'unknownFields': safeUnknownFields,
      'components': [
        for (final component in inspection.components) component.toJson(),
      ],
      'warnings': warnings.toSet().toList()..sort(),
      'fileCount': inspection.fileCount,
      'totalBytes': inspection.totalBytes,
    };
    final record = ExtensionRecord(
      id: id,
      kind: 'plugin',
      name: inspection.manifest.name,
      source: source,
      status: ExtensionLifecycleStatus.installed,
      updatedAt: updatedAt,
      version: inspection.manifest.version,
      digest: 'sha256:' + inspection.sourceDigest,
      compatibility: const {
        'host': 'kelivo',
        'pluginFormat': 'claude-plugin',
      },
      permissions: const <String>[],
      entryPoint: '.claude-plugin/plugin.json',
      installedAt: installedAt,
      metadata: metadata,
    );
    record.validate();
    return record;
  }

  Future<_PluginInventory> _buildInventory(Directory root) async {
    final rootType = await FileSystemEntity.type(
      root.path,
      followLinks: false,
    );
    if (rootType != FileSystemEntityType.directory) {
      throw const FormatException('plugin_root_not_directory');
    }

    final files = <String, _PluginFile>{};
    final directories = <String>{};
    var totalBytes = 0;
    var visitedEntries = 0;

    Future<void> visit(Directory directory, String relative, int depth) async {
      if (depth > 16) {
        throw const FormatException('plugin_directory_depth_limit');
      }
      final children = await directory.list(followLinks: false).toList();
      children.sort((a, b) => a.path.compareTo(b.path));
      for (final entity in children) {
        visitedEntries++;
        if (visitedEntries > _maxPluginEntries) {
          throw const FormatException('plugin_entry_count_limit');
        }
        final childRelative = relative.isEmpty
            ? p.posix.basename(entity.path)
            : relative + '/' + p.posix.basename(entity.path);
        _validateFilesystemRelativePath(childRelative);
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.link) {
          throw const FormatException('plugin_symlink_not_allowed');
        }
        if (type == FileSystemEntityType.directory) {
          directories.add(childRelative);
          await visit(Directory(entity.path), childRelative, depth + 1);
        } else if (type == FileSystemEntityType.file) {
          if (files.length >= _maxPluginFiles) {
            throw const FormatException('plugin_file_count_limit');
          }
          final file = File(entity.path);
          final size = await file.length();
          if (size > _maxPluginFileBytes) {
            throw const FormatException('plugin_file_size_limit');
          }
          totalBytes += size;
          if (totalBytes > _maxPluginBytes) {
            throw const FormatException('plugin_total_size_limit');
          }
          final digest = sha256.convert(await file.readAsBytes()).toString();
          files[childRelative] = _PluginFile(
            file: file,
            sizeBytes: size,
            digest: digest,
          );
        } else {
          throw const FormatException('plugin_special_file_not_allowed');
        }
      }
    }

    await visit(root, '', 0);
    final digestInput = StringBuffer();
    final sortedPaths = files.keys.toList()..sort();
    for (final path in sortedPaths) {
      digestInput
        ..write(path)
        ..write('\u0000')
        ..write(files[path]!.digest)
        ..write('\n');
    }
    return _PluginInventory(
      files: Map<String, _PluginFile>.unmodifiable(files),
      directories: Set<String>.unmodifiable(directories),
      digest: sha256.convert(utf8.encode(digestInput.toString())).toString(),
      totalBytes: totalBytes,
    );
  }

  Future<void> _copyInventory(
    _PluginInventory inventory,
    Directory destination,
  ) async {
    for (final path in inventory.files.keys.toList()..sort()) {
      final source = inventory.files[path]!.file;
      final destinationPath = p.join(destination.path, path);
      await Directory(p.dirname(destinationPath)).create(recursive: true);
      await source.copy(destinationPath);
    }
  }
}

String? _normalizePluginArchivePath(String raw) {
  if (raw.isEmpty ||
      raw.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(raw) ||
      raw.contains(String.fromCharCode(92)) ||
      raw.contains('\u0000')) {
    throw const FormatException('plugin_archive_path_unsafe');
  }
  var path = raw;
  while (path.startsWith('./')) {
    path = path.substring(2);
  }
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.isEmpty) return null;
  _validateFilesystemRelativePath(path);
  final normalized = p.posix.normalize(path);
  _validateFilesystemRelativePath(normalized);
  return normalized;
}

class _LimitedPluginOutputStream extends OutputFileStream {
  _LimitedPluginOutputStream(String path, this.maxBytes)
      : super.withFileHandle(FileHandle(path, mode: FileAccess.write));

  final int maxBytes;

  void _check(int count) {
    if (length + count > maxBytes) {
      throw const FormatException('plugin_archive_expanded_size_limit');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }
}

String _normalizeDeclaredPath(String raw) {
  if (raw.trim().isEmpty) {
    throw const FormatException('plugin_path_empty');
  }
  late final String decoded;
  try {
    decoded = Uri.decodeComponent(raw.trim());
  } catch (_) {
    throw const FormatException('plugin_path_encoding');
  }
  var value = decoded;
  while (value.startsWith('./')) {
    value = value.substring(2);
  }
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  _validateFilesystemRelativePath(value);
  return value;
}

void _validateFilesystemRelativePath(String path) {
  if (path.isEmpty ||
      path.length > 2048 ||
      path.startsWith('/') ||
      path.contains(String.fromCharCode(92)) ||
      path.contains(':') ||
      path.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
    throw const FormatException('plugin_path_unsafe');
  }
  final segments = path.split('/');
  if (segments.any(
    (segment) => segment.isEmpty || segment == '.' || segment == '..',
  )) {
    throw const FormatException('plugin_path_unsafe');
  }
}

Object? _sanitizeMetadata(
  Object? value,
  List<String> warnings,
  String fieldPath, [
  int depth = 0,
]) {
  if (depth > 16) {
    throw const FormatException('plugin_manifest_metadata_too_deep');
  }
  if (value is Map) {
    if (value.length > 2048) {
      throw const FormatException('plugin_manifest_metadata_too_many_fields');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (_sensitiveManifestKey.hasMatch(key)) {
        warnings.add('sensitive_manifest_field_omitted:' + fieldPath + '.' + key);
        continue;
      }
      result[key] = _sanitizeMetadata(
        entry.value,
        warnings,
        fieldPath + '.' + key,
        depth + 1,
      );
    }
    return result;
  }
  if (value is List) {
    if (value.length > 2048) {
      throw const FormatException('plugin_manifest_metadata_too_many_items');
    }
    return [
      for (var index = 0; index < value.length; index++)
        _sanitizeMetadata(
          value[index],
          warnings,
          fieldPath,
          depth + 1,
        ),
    ];
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  warnings.add('unsupported_manifest_value_omitted:' + fieldPath);
  return null;
}

String? _safePublicUrl(String? value) {
  if (value == null) return null;
  final parsed = Uri.tryParse(value);
  if (parsed == null ||
      (parsed.scheme != 'https' && parsed.scheme != 'http') ||
      parsed.host.isEmpty ||
      parsed.userInfo.isNotEmpty ||
      parsed.queryParameters.keys.any(_sensitiveManifestKey.hasMatch) ||
      _sensitiveManifestKey.hasMatch(Uri.decodeComponent(parsed.fragment))) {
    return null;
  }
  return parsed.toString();
}
