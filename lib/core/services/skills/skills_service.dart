import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';
import '../../database/extension_entity_store.dart';
import '../extensions/extension_registry_repository.dart';
import '../../models/assistant.dart';
import '../../models/skill_record.dart';
import '../../models/skill_pack.dart';
import '../../models/extension_record.dart';
import 'core_guidance_service.dart';
import 'github_credential_store.dart';
import 'github_skill_ref.dart';
import 'skill.dart';
import 'skill_archive.dart';
import 'skill_compatibility.dart';
import 'skill_import_candidate.dart';
import 'skill_import_manifest.dart';
import 'skills_catalog_adapter.dart';
import 'skill_frontmatter.dart';
import 'skill_import_progress.dart';

export 'skill.dart';
export '../../models/skill_pack.dart';
export 'skill_import_progress.dart';
export 'skill_import_candidate.dart';
export 'skill_compatibility.dart';
export 'skills_catalog_adapter.dart' show SkillCatalogEntry;
export 'skill_frontmatter.dart' show SkillFrontmatter, slugify;
export 'skills_prompt.dart' show buildAvailableSkillsFragment;

final class _PreparedSkillsShUpdate {
  const _PreparedSkillsShUpdate({
    required this.skillId,
    required this.catalogId,
    required this.bundle,
    required this.files,
  });

  final String skillId;
  final String catalogId;
  final SkillCatalogPackage bundle;
  final Map<String, List<int>> files;
}

final class _PreparedSkillsShArchive {
  const _PreparedSkillsShArchive({
    required this.staging,
    required this.skillDirectory,
    required this.skillPath,
    required this.extraction,
    required this.ref,
    required this.revision,
    required this.commit,
  });

  final Directory staging;
  final Directory skillDirectory;
  final String skillPath;
  final Map<String, Object?> extraction;
  final GitHubSkillRef ref;
  final String revision;
  final String? commit;
}

class SkillsService extends ChangeNotifier {
  SkillsService({
    required this.store,
    ExtensionRegistryRepository? extensionRegistry,
    Directory? skillsDirectory,
    Directory? skillImportMetadataDirectory,
    http.Client? httpClient,
    GitHubCredentialStore? credentialStore,
    SkillsCatalogAdapter? skillsCatalogAdapter,
  }) : _injectedSkillsDirectory = skillsDirectory,
       _injectedSkillImportMetadataDirectory = skillImportMetadataDirectory,
       _extensionRegistry =
           extensionRegistry ?? ExtensionRegistryRepository(store),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _credentialStore = credentialStore ?? SecureGitHubCredentialStore() {
    _skillsCatalogAdapter = skillsCatalogAdapter ?? SkillsShAdapter(_httpClient);
    loaded = _load();
  }

  final ExtensionEntityStore store;
  final Directory? _injectedSkillsDirectory;
  final Directory? _injectedSkillImportMetadataDirectory;
  final ExtensionRegistryRepository _extensionRegistry;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final GitHubCredentialStore _credentialStore;
  late final SkillsCatalogAdapter _skillsCatalogAdapter;
  final List<Skill> _skills = <Skill>[];
  final List<SkillPack> _skillPacks = <SkillPack>[];
  final Map<String, ExtensionRecord> _skillExtensionRecords =
      <String, ExtensionRecord>{};

  late final Future<void> loaded;

  Directory? _skillsDirectory;
  Directory? _skillImportMetadataDirectory;
  Future<void> _mutationTail = Future<void>.value();
  bool _disposed = false;

  // Command-triggered rescans share the same queue as imports and settings
  // changes so an older disk snapshot cannot replace newer user choices.
  Future<T> _serializeMutation<T>(Future<T> Function() operation) {
    final result = _mutationTail.then((_) => operation());
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  List<Skill> get skills => List.unmodifiable(_skills);

  List<SkillPack> get skillPacks => List.unmodifiable(_skillPacks);

  Directory get skillsDirectory {
    final dir = _skillsDirectory ?? _injectedSkillsDirectory;
    if (dir == null) {
      throw StateError('SkillsService.loaded has not completed');
    }
    return dir;
  }

  /// Returns the read-only import manifest/report for an installed Skill.
  /// Missing manifests indicate a legacy installation predating Phase 13A.
  Future<Map<String, Object?>?> getImportReport(String skillId) async {
    await loaded;
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}$').hasMatch(skillId)) {
      throw const FormatException('invalid_skill_manifest_id');
    }
    final root = await _ensureSkillImportMetadataRoot();
    final file = File(p.join(root.path, 'skills', '$skillId.json'));
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('invalid_skill_import_manifest');
    }
    return Map<String, Object?>.from(decoded);
  }

  /// Returns an import manifest with a current static requirement inventory.
  /// Legacy Skills are re-analysed from their installed files and only the
  /// requirement sidecar is upgraded; no Skill content is executed or changed.
  Future<Map<String, Object?>?> getImportReportWithRequirements(
    String skillId,
  ) => _serializeMutation(() async {
    await loaded;
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}$').hasMatch(skillId)) {
      throw const FormatException('invalid_skill_manifest_id');
    }
    final existing = await getImportReport(skillId);
    final currentRequirements = existing?['requirements'];
    final sourceDigest = existing?['sourceDigest']?.toString();
    final requirementDigest = existing?['requirementInventorySourceDigest']?.toString();
    if (currentRequirements is Map &&
        currentRequirements['schemaVersion'] != null &&
        sourceDigest != null && sourceDigest == requirementDigest) {
      final assessment = existing?['environmentAssessment'];
      if (assessment is Map && assessment['sourceDigest'] != sourceDigest) {
        final cleaned = Map<String, Object?>.from(existing!)
          ..remove('environmentAssessment');
        final metadataRoot = await _ensureSkillImportMetadataRoot();
        final reportsDirectory = Directory(p.join(metadataRoot.path, 'skills'));
        await reportsDirectory.create(recursive: true);
        final destination = File(p.join(reportsDirectory.path, '$skillId.json'));
        final temporary = File('${destination.path}.stale-readiness.tmp');
        await temporary.writeAsString(
          const JsonEncoder.withIndent('  ').convert(cleaned),
          flush: true,
        );
        if (await destination.exists()) await destination.delete();
        await temporary.rename(destination.path);
        return cleaned;
      }
      return existing;
    }

    final skillDirectory = Directory(p.join(skillsDirectory.path, skillId));
    if (!await skillDirectory.exists()) return existing;

    final source = existing?['source'];
    final sourceMap = source is Map ? source : const <Object?, Object?>{};
    final shared = existing?['sharedResources'];
    Directory? sharedDirectory;
    String? sharedSetId;
    var sharedPaths = <String>[];
    if (shared is Map) {
      final rawSetId = shared['setId'];
      if (rawSetId is String && RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(rawSetId)) {
        final metadataRoot = await _ensureSkillImportMetadataRoot();
        final candidate = Directory(p.join(metadataRoot.path, 'repositories', rawSetId, 'shared'));
        if (await candidate.exists()) {
          sharedDirectory = candidate;
          sharedSetId = rawSetId;
          final paths = shared['paths'];
          if (paths is List) sharedPaths = paths.whereType<String>().toList();
        }
      }
    }
    final skippedEntries = <SkillImportSkippedEntry>[];
    final rawSkipped = existing?['skipped'];
    if (rawSkipped is List) {
      for (final entry in rawSkipped.whereType<Map>()) {
        final path = entry['path'];
        final reason = entry['reason'];
        if (path is String && reason is String) {
          skippedEntries.add(SkillImportSkippedEntry(
            path: path,
            reason: reason,
            scope: entry['scope']?.toString() ?? 'skill',
          ));
        }
      }
    }
    final completenessNotes = (existing?['completenessNotes'] as List? ?? const [])
        .whereType<String>().toList(growable: false);
    final manifest = await SkillImportAnalyzer.analyzeDirectory(
      skillId: skillId,
      directory: skillDirectory,
      sourceType: sourceMap['type']?.toString() ?? 'legacy_installed',
      sourceUrl: sourceMap['url']?.toString(),
      repository: sourceMap['repository']?.toString(),
      ref: sourceMap['ref']?.toString(),
      commit: sourceMap['commit']?.toString(),
      sharedDirectory: sharedDirectory,
      sharedResourceSetId: sharedSetId,
      sharedResourcePaths: sharedPaths,
      skipped: skippedEntries,
      completeness: existing?['completeness']?.toString() ?? 'unknown',
      completenessNotes: completenessNotes,
    );

    final upgraded = existing == null
        ? Map<String, Object?>.from(manifest.toJson())
        : Map<String, Object?>.from(existing);
    upgraded
      ..['schemaVersion'] = SkillImportManifest.currentSchemaVersion
      ..['sourceDigest'] = manifest.sourceDigest
      ..['files'] = manifest.files.map((entry) => entry.toJson()).toList(growable: false)
      ..['capabilities'] = manifest.capabilities.map((entry) => entry.toJson()).toList(growable: false)
      ..['dependencies'] = manifest.dependencies.map((entry) => entry.toJson()).toList(growable: false)
      ..['skipped'] = manifest.skipped.map((entry) => entry.toJson()).toList(growable: false)
      ..['completeness'] = manifest.completeness
      ..['completenessNotes'] = manifest.completenessNotes
      ..['requirements'] = manifest.requirements
      ..['requirementInventoryUpdatedAt'] = DateTime.now().toUtc().toIso8601String()
      ..['requirementInventorySourceDigest'] = manifest.sourceDigest;
    // A rebuilt requirement inventory invalidates any previously persisted
    // environment assessment. Never reuse readiness evidence after the Skill
    // source or requirement inventory changes.
    upgraded.remove('environmentAssessment');
    final metadataRoot = await _ensureSkillImportMetadataRoot();
    final reportsDirectory = Directory(p.join(metadataRoot.path, 'skills'));
    await reportsDirectory.create(recursive: true);
    final destination = File(p.join(reportsDirectory.path, '$skillId.json'));
    final temporary = File('${destination.path}.requirements.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(upgraded),
      flush: true,
    );
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
    return upgraded;
  });

  /// Persists a read-only live environment/readiness assessment alongside
  /// the import manifest. The assessment is bound to the current source digest
  /// so Skill edits or updates cannot reuse stale validation evidence.
  Future<void> saveEnvironmentAssessment(
    String skillId,
    Map<String, Object?> assessment,
  ) => _serializeMutation(() async {
    await loaded;
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}$').hasMatch(skillId)) {
      throw const FormatException('invalid_skill_manifest_id');
    }
    final existing = await getImportReport(skillId);
    if (existing == null) return;
    final sourceDigest = existing['sourceDigest']?.toString();
    if (sourceDigest == null || sourceDigest.isEmpty) {
      throw const FormatException('skill_source_digest_missing');
    }
    final assessedDigest = assessment['sourceDigest']?.toString();
    if (assessedDigest == null || assessedDigest.isEmpty) {
      throw const FormatException('skill_assessment_source_digest_required');
    }
    if (assessedDigest != sourceDigest) {
      throw StateError('skill_source_changed_during_readiness_check');
    }
    final persisted = Map<String, Object?>.from(assessment)
      ..['sourceDigest'] = sourceDigest
      ..['persistedAt'] = DateTime.now().toUtc().toIso8601String();
    final updated = Map<String, Object?>.from(existing)
      ..['environmentAssessment'] = persisted;
    final root = await _ensureSkillImportMetadataRoot();
    final reportsDirectory = Directory(p.join(root.path, 'skills'));
    await reportsDirectory.create(recursive: true);
    final destination = File(p.join(reportsDirectory.path, '$skillId.json'));
    final temporary = File('${destination.path}.readiness.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(updated),
      flush: true,
    );
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
  });

  Future<void> _load() => _serializeMutation(() async {
    final root = await _ensureRoot();
    await CoreGuidanceService.ensureInstalled(root);
    await _rescan();
  });

  Future<Directory> _ensureRoot() async {
    final dir =
        _injectedSkillsDirectory ?? await AppDirectories.getSkillsDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _skillsDirectory = dir;
    return dir;
  }

  Future<Directory> _ensureSkillImportMetadataRoot() async {
    final cached = _skillImportMetadataDirectory;
    if (cached != null && await cached.exists()) return cached;
    final dir = _injectedSkillImportMetadataDirectory ??
        (_injectedSkillsDirectory != null
            ? Directory(p.join(_injectedSkillsDirectory.parent.path, 'skill-import-metadata'))
            : await AppDirectories.getSkillImportMetadataDirectory());
    await dir.create(recursive: true);
    _skillImportMetadataDirectory = dir;
    return dir;
  }

  Future<void> rescan() => _serializeMutation(_rescan);

  Future<void> _rescan() async {
    if (_disposed) return;
    final root = await _ensureRoot();
    final entities = await store.listByKind(ExtensionEntityStore.kindSkill);
    final records = <String, SkillRecord>{
      for (final entity in entities)
        entity.id: SkillRecord.fromJson(entity.payload),
    };

    final diskIds = <String>{};
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (id.isEmpty || id.startsWith('.')) continue;
      diskIds.add(id);
    }

    for (final id in List<String>.from(records.keys)) {
      final md = File(p.join(root.path, id, 'SKILL.md'));
      if (!await md.exists()) {
        await store.delete(ExtensionEntityStore.kindSkill, id);
        await _extensionRegistry.remove('skill', id);
        _skillExtensionRecords.remove(id);
        records.remove(id);
      }
    }

    for (final id in diskIds) {
      if (records.containsKey(id)) continue;
      final md = File(p.join(root.path, id, 'SKILL.md'));
      if (!await md.exists()) continue;
      final now = DateTime.now().toUtc();
      final record = SkillRecord(
        id: id,
        source: SkillSource.file,
        installedAt: now,
        updatedAt: now,
      );
      await store.upsert(ExtensionEntityStore.kindSkill, id, record.toJson());
      records[id] = record;
    }

    final next = <Skill>[];
    for (final record in records.values) {
      final skill = await _skillFromDisk(root, record);
      await _syncSkillExtension(skill);
      next.add(skill);
    }
    next.sort((a, b) => a.record.id.compareTo(b.record.id));
    await _loadSkillPacksAndDetectRepositories(next);
    if (_disposed) return;
    _skills
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Future<Skill> importFromText(String markdown) {
    return _importMarkdown(markdown, SkillSource.paste);
  }

  Future<Skill> importFromFile(
    String hostPath, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    var cancelled = false;
    unawaited(
      cancelSignal?.then<void>((_) {
        cancelled = true;
      }),
    );
    Future<void> checkCancelled() async {
      if (cancelSignal != null) await Future<void>.value();
      if (cancelled) throw http.RequestAbortedException();
    }

    await checkCancelled();
    final file = File(hostPath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', hostPath);
    }
    final ext = p.extension(hostPath).toLowerCase();
    if (ext == '.md') {
      final markdown = await file.readAsString();
      await checkCancelled();
      return _importMarkdown(markdown, SkillSource.file);
    }
    if (ext == '.zip') {
      final root = await _ensureRoot();
      final staging = await root.createTemp('.import-');
      try {
        await checkCancelled();
        return await _importArchive(
          file,
          staging,
          SkillSource.file,
          onProgress: onProgress,
          checkCancelled: checkCancelled,
        );
      } finally {
        if (await staging.exists()) await staging.delete(recursive: true);
      }
    }
    throw FormatException('Unsupported skill file type: $ext');
  }

  /// Import a local Skill source that may contain one Skill, several repository
  /// Skills, or a package ZIP containing one ZIP per Skill. Complete Skill
  /// folders are preserved; scripts are never executed during import.
  Future<List<Skill>> importSkillsFromFile(
    String hostPath, {
    required Future<Set<String>?> Function(
      List<SkillImportCandidate> candidates,
    ) chooseSkills,
    SkillSource source = SkillSource.file,
    String? sourceUrl,
    String? repository,
    String? sourceRef,
    String? sourceRevision,
    String? sourceSubpath,
    String? commit,
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    var cancelled = false;
    unawaited(
      cancelSignal?.then<void>((_) {
        cancelled = true;
      }),
    );
    void checkCancelled() {
      if (cancelled) throw http.RequestAbortedException();
    }

    final sourceFile = File(hostPath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('File not found', hostPath);
    }
    final extension = p.extension(hostPath).toLowerCase();
    if (!const {'.md', '.skill', '.zip'}.contains(extension)) {
      throw FormatException('Unsupported Skill source type: $extension');
    }

    // A `.skill` file is normally Markdown. Some distributors package a
    // Skill archive with that suffix, so sniff the ZIP signature as well.
    final prefix = await sourceFile.open();
    List<int> signature;
    try {
      signature = await prefix.read(4);
    } finally {
      await prefix.close();
    }
    final isZipPayload = signature.length >= 2 &&
        signature[0] == 0x50 && signature[1] == 0x4b;
    if (extension == '.md' || (extension == '.skill' && !isZipPayload)) {
      checkCancelled();
      final markdown = await sourceFile.readAsString();
      final skill = await _importMarkdown(markdown, source);
      if (sourceUrl != null) {
        await _syncSkillExtension(
          skill,
          sourceUri: sourceUrl,
          sourceRef: sourceRef,
          sourceSubpath: sourceSubpath,
          sourceRevision: sourceRevision,
        );
      }
      return <Skill>[skill];
    }

    onProgress?.call(const SkillImportProgress(SkillImportPhase.resolving));
    final root = await _ensureRoot();
    final staging = await root.createTemp('.bundle-import-');
    final installedIds = <String>[];
    ({String id, Directory directory})? sharedBundle;
    try {
      checkCancelled();
      onProgress?.call(const SkillImportProgress(SkillImportPhase.extracting));
      late Directory extracted;
      late Map<String, Object?> extraction;
      extracted = Directory(p.join(staging.path, 'repository'));
      try {
        extraction = await compute(_extractRepositoryArchive, (
          sourceFile.path,
          extracted.path,
          null,
          false,
        ));
      } on FormatException catch (error) {
        if (!error.message.toString().contains('SKILL.md not found')) rethrow;
        // Multi-Skill distribution ZIPs often contain Skills/*.zip and
        // package-level guides, rather than SKILL.md at the outer level.
        extracted = Directory(p.join(staging.path, 'nested-bundle'));
        extraction = await compute(_extractNestedSkillBundle, (
          sourceFile.path,
          extracted.path,
        ));
      }
      checkCancelled();

      final folders = _stringMap(extraction['skills']);
      if (folders.isEmpty) {
        throw const FormatException('no_agent_skills_found');
      }
      final sharedPaths = (extraction['sharedPaths'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false);
      final sharedName = extraction['sharedDirectory'] as String?;
      final sharedDirectory = sharedName == null
          ? null
          : Directory(p.join(extracted.path, sharedName));
      final sharedBytes = await _directoryFileBytes(sharedDirectory);
      final candidates = <SkillImportCandidate>[];
      final candidateFolders = <String, Directory>{};
      for (final entry in folders.entries) {
        checkCancelled();
        final folder = Directory(p.join(extracted.path, entry.value));
        final markdownFile = File(p.join(folder.path, 'SKILL.md'));
        if (!await markdownFile.exists()) {
          throw FormatException('skill_candidate_missing_skill_md:${entry.key}');
        }
        final parsed = SkillFrontmatter.parse(await markdownFile.readAsString());
        final directoryName = entry.key == '.'
            ? null
            : p.posix.basename(entry.key);
        final filePaths = <String>[];
        var fileCount = 0;
        await for (final entity in folder.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          fileCount++;
          filePaths.add(
            p.relative(entity.path, from: folder.path).replaceAll('\\', '/'),
          );
        }
        final compatibility = SkillCompatibilityAnalyzer.analyze(
          parsed,
          directoryName: directoryName,
          files: filePaths,
        );
        candidates.add(
          SkillImportCandidate(
            path: entry.key,
            name: parsed.name.isEmpty ? entry.key : parsed.name,
            description: parsed.description,
            bodyPreview: parsed.body.trim().substring(
              0,
              parsed.body.trim().length > 1200
                  ? 1200
                  : parsed.body.trim().length,
            ),
            license: parsed.license,
            environmentCompatibility: parsed.compatibility,
            metadata: Map.unmodifiable(parsed.metadata),
            allowedTools: parsed.allowedTools,
            fileCount: fileCount,
            sharedFileCount: sharedPaths.length,
            sharedBytes: sharedBytes,
            compatibility: compatibility,
          ),
        );
        candidateFolders[entry.key] = folder;
      }
      candidates.sort((a, b) => a.path.compareTo(b.path));
      final selected = await chooseSkills(List.unmodifiable(candidates));
      checkCancelled();
      if (selected == null || selected.isEmpty) return const <Skill>[];
      final byPath = <String, SkillImportCandidate>{
        for (final candidate in candidates) candidate.path: candidate,
      };
      if (selected.any((path) => !byPath.containsKey(path))) {
        throw const FormatException('invalid_skill_selection');
      }
      final invalid = selected
          .map((path) => byPath[path]!)
          .where((candidate) => !candidate.compatibility.isImportable)
          .toList();
      if (invalid.isNotEmpty) {
        throw FormatException(
          'Selected Skill is not Agent Skills compatible: '
          '${invalid.map((candidate) => '${candidate.path}: '
              '${candidate.compatibility.errors.join('; ')}').join(' | ')}',
        );
      }

      sharedBundle = await _persistRepositorySharedResources(
        sourceDirectory: sharedDirectory,
        paths: sharedPaths,
        repository: repository ?? 'local-bundle:${p.basename(hostPath)}',
        ref: sourceRef ?? 'local',
        commit: commit,
      );
      final skipped = _skippedEntries(extraction['skipped']);
      onProgress?.call(const SkillImportProgress(SkillImportPhase.installing));
      final orderedSelection = selected.toList()..sort();
      final result = await _serializeMutation(() async {
        final imported = <Skill>[];
        try {
          for (final path in orderedSelection) {
            checkCancelled();
            final parsed = SkillFrontmatter.parse(
              await File(p.join(candidateFolders[path]!.path, 'SKILL.md'))
                  .readAsString(),
            );
            final id = await _allocateId(slugify(parsed.name));
            final destination = Directory(p.join(root.path, id));
            await candidateFolders[path]!.rename(destination.path);
            installedIds.add(id);
            final skill = await _registerImport(
              root,
              id,
              source,
              writeDefaultImportManifest: false,
            );
            await _writeSkillImportManifest(
              skillId: id,
              skillDirectory: destination,
              sourceType: source.name,
              sourceUrl: sourceUrl,
              repository: repository,
              ref: sourceRef,
              commit: commit,
              sharedDirectory: sharedBundle?.directory,
              sharedResourceSetId: sharedBundle?.id,
              sharedResourcePaths: sharedPaths,
              skipped: skipped,
              executableOverrides: _skillModeMap(
                extraction['skillExecutableModes'],
                path,
              ),
              sharedExecutableOverrides: _stringBoolMap(
                extraction['sharedExecutableModes'],
              ),
              completeness: skipped.isEmpty ? 'complete' : 'partial',
              completenessNotes: skipped.isEmpty
                  ? const []
                  : const ['One or more symbolic links or auxiliary entries were skipped.'],
            );
            if (sourceUrl != null) {
              await _syncSkillExtension(
                skill,
                sourceUri: sourceUrl,
                sourceRef: sourceRef,
                sourceSubpath: sourceSubpath ?? path,
                sourceRevision: sourceRevision,
              );
            }
            imported.add(skill);
          }
          return List<Skill>.unmodifiable(imported);
        } catch (_) {
          for (final id in installedIds) {
            await store.delete(ExtensionEntityStore.kindSkill, id);
            await _extensionRegistry.remove('skill', id);
            await _deleteSkillImportManifest(id);
            final directory = Directory(p.join(root.path, id));
            if (await directory.exists()) await directory.delete(recursive: true);
            _skills.removeWhere((item) => item.record.id == id);
          }
          final bundleToRemove = sharedBundle;
          if (bundleToRemove != null) {
            final bundleParent = bundleToRemove.directory.parent;
            if (await bundleParent.exists()) {
              await bundleParent.delete(recursive: true);
            }
          }
          notifyListeners();
          rethrow;
        }
      });
      if (result.isNotEmpty) {
        await _serializeMutation(() async {
          await _loadSkillPacksAndDetectRepositories(_skills);
          if (!_disposed) notifyListeners();
        });
      }
      return result;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Copy a local Skill folder into the managed Skills directory without
  /// buffering the complete folder in RAM. Symlinks are never followed.
  Future<Skill> importFromDirectory(
    String hostPath, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    var cancelled = false;
    unawaited(
      cancelSignal?.then<void>((_) {
        cancelled = true;
      }),
    );
    Future<void> checkCancelled() async {
      if (cancelSignal != null) await Future<void>.value();
      if (cancelled) throw http.RequestAbortedException();
    }

    final source = Directory(hostPath);
    if (!await source.exists() ||
        await FileSystemEntity.type(source.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw FileSystemException('Skill directory not found or is a link', hostPath);
    }
    final root = await _ensureRoot();
    final staging = await root.createTemp('.folder-import-');
    final stagedFiles = Directory(p.join(staging.path, 'files'));
    var totalBytes = 0;
    var fileCount = 0;
    final skipped = <SkillImportSkippedEntry>[];
    final executableModes = <String, bool?>{};
    try {
      await stagedFiles.create(recursive: true);
      await for (final entity in source.list(
        recursive: true,
        followLinks: false,
      )) {
        await checkCancelled();
        final relative = p
            .relative(entity.path, from: source.path)
            .replaceAll('\\', '/');
        if (entity is Link) {
          skipped.add(SkillImportSkippedEntry(
            path: relative,
            reason: 'symbolic_link_not_followed',
          ));
          continue;
        }
        if (entity is! File) continue;
        final normalized = p.posix.normalize(relative);
        if (normalized.isEmpty ||
            normalized == '.' ||
            normalized.startsWith('/') ||
            normalized.split('/').contains('..')) {
          throw const FormatException('unsafe_skill_directory_path');
        }
        fileCount++;
        if (fileCount > SkillImportAnalyzer.maxFiles) {
          throw const FormatException('skill_directory_file_limit');
        }
        final sourceStat = await entity.stat();
        if (sourceStat.size > SkillImportAnalyzer.maxFileBytes) {
          throw FormatException('skill_directory_file_too_large:$normalized');
        }
        if (!Platform.isWindows) {
          executableModes[normalized] = (sourceStat.mode & 0x49) != 0;
        }
        final outputFile = File(p.join(stagedFiles.path, normalized));
        await outputFile.parent.create(recursive: true);
        final sink = outputFile.openWrite();
        try {
          await for (final chunk in entity.openRead()) {
            await checkCancelled();
            totalBytes += chunk.length;
            if (totalBytes > kSkillImportMaxExtractedBytes) {
              throw const FormatException('skill_directory_exceeds_500_mb');
            }
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }
        onProgress?.call(
          SkillImportProgress(
            SkillImportPhase.downloading,
            receivedBytes: totalBytes,
          ),
        );
      }
      await checkCancelled();
      final markdownFile = File(p.join(stagedFiles.path, 'SKILL.md'));
      if (!await markdownFile.exists()) {
        throw const FormatException('SKILL.md not found in selected folder');
      }
      final parsed = SkillFrontmatter.parse(await markdownFile.readAsString());
      final errors = parsed.validate(
        directoryName: p.basename(p.normalize(source.path)),
      );
      if (errors.isNotEmpty) {
        throw FormatException('Invalid SKILL.md: ${errors.join(', ')}');
      }
      onProgress?.call(const SkillImportProgress(SkillImportPhase.installing));
      return await _serializeMutation(() async {
        await checkCancelled();
        final id = await _allocateId(slugify(parsed.name));
        final destination = Directory(p.join(root.path, id));
        await stagedFiles.rename(destination.path);
        try {
          await checkCancelled();
          final skill = await _registerImport(
            root, id, SkillSource.file, writeDefaultImportManifest: false,
          );
          await _writeSkillImportManifest(
            skillId: id,
            skillDirectory: destination,
            sourceType: SkillSource.file.name,
            skipped: skipped,
            executableOverrides: executableModes,
          );
          return skill;
        } catch (_) {
          await store.delete(ExtensionEntityStore.kindSkill, id);
          await _extensionRegistry.remove('skill', id);
          await _deleteSkillImportManifest(id);
          _skills.removeWhere((item) => item.record.id == id);
          if (await destination.exists()) {
            await destination.delete(recursive: true);
          }
          rethrow;
        }
      });
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Search public GitHub repositories whose README matches Skill-related
  /// terms. Results are candidates and are not treated as validated Skills.
  Future<List<Map<String, Object?>>> searchGitHubRepositories(
    String query, {
    int limit = 8,
  }) async {
    await loaded;
    final normalized = query.trim();
    if (normalized.isEmpty || normalized.length > 160) {
      throw const FormatException('invalid_extension_search_query');
    }
    final uri = Uri.https('api.github.com', '/search/repositories', {
      'q': '$normalized in:readme',
      'sort': 'stars',
      'order': 'desc',
      'per_page': '${limit.clamp(1, 10)}',
    });
    final response = await _httpClient.get(uri, headers: _githubHeaders);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'GitHub repository search failed (${response.statusCode})',
        uri: uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['items'] is! List) {
      throw const FormatException('invalid_github_search_response');
    }
    return [
      for (final item in (decoded['items'] as List).whereType<Map>())
        <String, Object?>{
          'id': (item['full_name'] ?? '').toString(),
          'name': (item['name'] ?? '').toString(),
          'fullName': (item['full_name'] ?? '').toString(),
          'description': (item['description'] ?? '').toString(),
          'url': (item['html_url'] ?? '').toString(),
          'stars': (item['stargazers_count'] as num?)?.toInt() ?? 0,
          'language': item['language']?.toString(),
          'defaultBranch': item['default_branch']?.toString(),
          'updatedAt': item['updated_at']?.toString(),
        },
    ];
  }

  /// Returns whether a private-repository read token is stored in secure storage.
  Future<bool> hasGitHubPrivateAccess() async =>
      (await _credentialStore.readToken())?.isNotEmpty ?? false;

  /// Validate a GitHub token against `/user` before storing it. A token is
  /// accepted only after GitHub confirms it; its value is never returned.
  Future<void> saveGitHubPrivateAccessToken(String rawToken) async {
    final token = rawToken.trim();
    if (token.length < 20 || token.length > 512 ||
        token.contains(RegExp(r'\s'))) {
      throw const FormatException('invalid_github_token_format');
    }
    final uri = Uri.https('api.github.com', '/user');
    final response = await _httpClient.get(uri, headers: {
      ..._githubHeaders,
      'Authorization': 'Bearer $token',
      'X-GitHub-Api-Version': '2022-11-28',
    });
    if (response.statusCode != 200) {
      throw HttpException(
        'GitHub rejected the token (${response.statusCode}). Check that it is '
        'valid and has read access to repository contents.',
        uri: uri,
      );
    }
    await _credentialStore.writeToken(token);
  }

  Future<void> clearGitHubPrivateAccess() => _credentialStore.clearToken();

  Future<List<SkillCatalogEntry>> searchSkillsCatalog(
    String query, {
    int limit = 10,
  }) async {
    await loaded;
    return _skillsCatalogAdapter.search(query, limit: limit);
  }

  /// Inspect a skills.sh entry without installing it or executing any files.
  Future<Map<String, Object?>> inspectSkillsCatalog(String id) async {
    await loaded;
    final bundle = await _skillsCatalogAdapter.resolve(id);
    final markdownBytes = bundle.files['SKILL.md'];
    if (markdownBytes == null) {
      throw const FormatException('skills_catalog_skill_md_missing');
    }
    final markdown = utf8.decode(markdownBytes, allowMalformed: false);
    final parsed = SkillFrontmatter.parse(markdown);
    final compatibility = SkillCompatibilityAnalyzer.analyze(
      parsed,
      directoryName: id.split('/').last,
      files: bundle.files.keys,
    );
    final scriptCount = bundle.files.keys.where(_isSkillScript).length;
    final body = parsed.body.trim();
    return <String, Object?>{
      'id': id,
      'name': parsed.name,
      'description': parsed.description,
      'license': parsed.license,
      'compatibilityRequirements': parsed.compatibility,
      'metadata': parsed.metadata,
      'allowedToolsHint': parsed.allowedTools,
      'source': bundle.sourceUrl,
      'revision': bundle.hash,
      'fileCount': bundle.files.length,
      'transportComplete': bundle.transportComplete,
      'unsupportedPaths': bundle.unsupportedPaths,
      'transportNotes': bundle.notes,
      'scriptCount': scriptCount,
      'hasScripts': scriptCount > 0,
      'scriptsAreNotExecuted': true,
      'compatibility': compatibility.toJson(),
      'bodyPreview': body.substring(0, body.length > 4000 ? 4000 : body.length),
    };
  }

  /// Install one standard Skill returned by skills.sh. Additional files are
  /// preserved byte-for-byte after UTF-8 decoding; scripts are never executed.
  Future<Skill> importFromSkillsCatalog(String id) async {
    await loaded;
    final bundle = await _skillsCatalogAdapter.resolve(id);
    _PreparedSkillsShArchive? archive;
    Object? archiveFailure;
    try {
      archive = await _prepareSkillsShArchive(bundle);
    } catch (error) {
      archiveFailure = error;
    }

    final preparedArchive = archive;
    if (preparedArchive != null) {
      try {
        final markdown = await File(
          p.join(preparedArchive.skillDirectory.path, 'SKILL.md'),
        ).readAsString();
        final parsed = SkillFrontmatter.parse(markdown);
        final errors = parsed.validate(
          directoryName: p.posix.basename(preparedArchive.skillPath),
        );
        if (errors.isNotEmpty) {
          throw FormatException('Invalid Agent Skill: ${errors.join(', ')}');
        }
        final extraction = preparedArchive.extraction;
        final sharedName = extraction['sharedDirectory'] as String?;
        final sharedPaths = (extraction['sharedPaths'] as List? ?? const [])
            .whereType<String>().toList(growable: false);
        final sharedSource = sharedName == null
            ? null
            : Directory(p.join(preparedArchive.staging.path, 'extracted', sharedName));
        final repository = '${preparedArchive.ref.owner}/${preparedArchive.ref.repo}';
        final sharedBundle = await _persistRepositorySharedResources(
          sourceDirectory: sharedSource,
          paths: sharedPaths,
          repository: repository,
          ref: preparedArchive.revision,
          commit: preparedArchive.commit,
          );
        final root = await _ensureRoot();
        return await _serializeMutation(() async {
          String? allocatedSkillId;
          Directory? destinationDirectory;
          try {
            final skillId = await _allocateId(slugify(parsed.name));
            allocatedSkillId = skillId;
            final destination = Directory(p.join(root.path, skillId));
            destinationDirectory = destination;
            await preparedArchive.skillDirectory.rename(destination.path);
            final skill = await _registerImport(
              root, skillId, SkillSource.skillsSh, writeDefaultImportManifest: false,
            );
            await _writeSkillImportManifest(
              skillId: skillId,
              skillDirectory: destination,
              sourceType: 'skills_sh',
              sourceUrl: bundle.sourceUrl,
              repository: repository,
              ref: preparedArchive.revision,
              commit: preparedArchive.commit,
              sharedDirectory: sharedBundle?.directory,
              sharedResourceSetId: sharedBundle?.id,
              sharedResourcePaths: sharedPaths,
              skipped: _skippedEntries(extraction['skipped']),
              executableOverrides: _skillModeMap(
                extraction['skillExecutableModes'], preparedArchive.skillPath,
              ),
              sharedExecutableOverrides: _stringBoolMap(
                extraction['sharedExecutableModes'],
              ),
              completeness: (extraction['skipped'] as List?)?.isNotEmpty == true
                  ? 'partial' : 'complete',
              completenessNotes: (extraction['skipped'] as List?)?.isNotEmpty == true
                  ? const ['One or more symbolic links were not imported.'] : const [],
            );
            await _syncSkillExtension(
              skill,
              sourceUri: bundle.sourceUrl,
              sourceRef: id,
              sourceRevision: bundle.hash ?? preparedArchive.revision,
            );
            await _loadSkillPacksAndDetectRepositories(_skills);
            if (!_disposed) notifyListeners();
            return skill;
          } catch (_) {
            final skillId = allocatedSkillId;
            if (skillId != null) {
              await store.delete(ExtensionEntityStore.kindSkill, skillId);
              await _extensionRegistry.remove('skill', skillId);
              await _deleteSkillImportManifest(skillId);
              _skills.removeWhere((item) => item.record.id == skillId);
            }
            final destination = destinationDirectory;
            if (destination != null && await destination.exists()) {
              await destination.delete(recursive: true);
            }
            if (sharedBundle != null && await sharedBundle.directory.parent.exists()) {
              await sharedBundle.directory.parent.delete(recursive: true);
            }
            rethrow;
          }
        });
      } finally {
        if (await preparedArchive.staging.exists()) {
          await preparedArchive.staging.delete(recursive: true);
        }
      }
    }

    // The catalog response is a text snapshot, not a binary-capable transport.
    // Keep backwards compatibility when it has a valid SKILL.md, but expose
    // that completeness could not be verified because the archive fallback failed.
    final markdownBytes = bundle.files['SKILL.md'];
    if (markdownBytes == null) {
      throw FormatException(
        'skills_catalog_skill_md_missing; GitHub archive fallback failed: '
        '${archiveFailure ?? 'unavailable'}',
      );
    }
    final markdown = utf8.decode(markdownBytes, allowMalformed: false);
    final parsed = SkillFrontmatter.parse(markdown);
    final directoryName = id.split('/').last;
    final errors = parsed.validate(directoryName: directoryName);
    if (errors.isNotEmpty) {
      throw FormatException('Invalid Agent Skill: ${errors.join(', ')}');
    }
    final safeFiles = <String, List<int>>{};
    for (final entry in bundle.files.entries) {
      final path = safeZipEntryName(entry.key);
      if (path == null || path != entry.key) {
        throw const FormatException('unsafe_skills_catalog_file_path');
      }
      safeFiles[path] = entry.value;
    }
    final skill = await _commitImport(
      name: parsed.name,
      files: safeFiles,
      source: SkillSource.skillsSh,
    );
    try {
      await _writeSkillImportManifest(
        skillId: skill.record.id,
        skillDirectory: Directory(skill.dir),
        sourceType: 'skills_sh',
        sourceUrl: bundle.sourceUrl,
        repository: bundle.repository,
        ref: bundle.hash,
        skipped: <SkillImportSkippedEntry>[
          ...bundle.unsupportedPaths.map((path) => SkillImportSkippedEntry(
            path: path,
            reason: 'skills_sh_api_did_not_provide_file_contents',
          )),
        ],
        completeness: 'unverified_text_snapshot',
        completenessNotes: <String>[
          ...bundle.notes,
          'GitHub archive fallback failed: ${archiveFailure ?? 'unavailable'}',
          'Binary and omitted repository assets are not verified by the text-only API snapshot.',
        ],
      );
    } catch (_) {
      await store.delete(ExtensionEntityStore.kindSkill, skill.record.id);
      await _extensionRegistry.remove('skill', skill.record.id);
      await _deleteSkillImportManifest(skill.record.id);
      final directory = Directory(skill.dir);
      if (await directory.exists()) await directory.delete(recursive: true);
      _skills.removeWhere((item) => item.record.id == skill.record.id);
      rethrow;
    }
    await _syncSkillExtension(
      skill,
      sourceUri: bundle.sourceUrl,
      sourceRef: id,
      sourceRevision: bundle.hash,
    );
    await _loadSkillPacksAndDetectRepositories(_skills);
    if (!_disposed) notifyListeners();
    return skill;
  }

  /// Download one GitHub repository/subfolder once, present every discovered
  /// Skill to [chooseSkills], then install exactly the selected candidates.
  /// Returning null/empty from the chooser cancels without writing anything.
  Future<List<Skill>> importFromGitHubRepository(
    String url, {
    required Future<Set<String>?> Function(
      List<SkillImportCandidate> candidates,
    ) chooseSkills,
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    var cancelled = false;
    unawaited(
      cancelSignal?.then<void>((_) {
        cancelled = true;
      }),
    );
    void checkCancelled() {
      if (cancelled) throw http.RequestAbortedException();
    }

    final ref = GitHubSkillRef.parse(url);
    onProgress?.call(const SkillImportProgress(SkillImportPhase.resolving));
    final revision = await _resolveGitHubRef(ref, cancelSignal: cancelSignal);
    checkCancelled();
    final root = await _ensureRoot();
    final staging = await root.createTemp('.repo-import-');
    final installedIds = <String>[];
    try {
      final zip = File(p.join(staging.path, 'download.zip'));
      await _downloadGitHubZip(
        ref,
        revision,
        zip,
        onProgress: onProgress,
        cancelSignal: cancelSignal,
      );
      checkCancelled();
      onProgress?.call(const SkillImportProgress(SkillImportPhase.extracting));
      if (ref.filePath != null) {
        final directFile = File(p.join(
          staging.path,
          'source-${p.posix.basename(ref.filePath!)}',
        ));
        await compute(_extractGitHubRepositoryFile, (
          zip.path,
          directFile.path,
          ref.filePath!,
          true,
        ));
        final commit = await _resolveGitHubCommitSha(ref, revision);
        return await importSkillsFromFile(
          directFile.path,
          chooseSkills: chooseSkills,
          source: SkillSource.github,
          sourceUrl: url,
          repository: '${ref.owner}/${ref.repo}',
          sourceRef: ref.ref ?? revision,
          sourceRevision: revision,
          sourceSubpath: ref.filePath,
          commit: commit,
          onProgress: onProgress,
          cancelSignal: cancelSignal,
        );
      }
      final extracted = Directory(p.join(staging.path, 'skills'));
      final extraction = await compute(_extractRepositoryArchive, (
        zip.path,
        extracted.path,
        ref.subdir,
        true,
      ));
      final folders = _stringMap(extraction['skills']);
      final sharedPaths = (extraction['sharedPaths'] as List? ?? const [])
          .whereType<String>().toList(growable: false);
      final sharedDirectoryName = extraction['sharedDirectory'] as String?;
      final sharedDirectory = sharedDirectoryName == null
          ? null : Directory(p.join(extracted.path, sharedDirectoryName));
      final sharedFileBytes = await _directoryFileBytes(sharedDirectory);
      final candidates = <SkillImportCandidate>[];
      final candidateFolders = <String, Directory>{};
      for (final entry in folders.entries) {
        checkCancelled();
        final folder = Directory(p.join(extracted.path, entry.value));
        final markdown = await File(p.join(folder.path, 'SKILL.md'))
            .readAsString();
        final parsed = SkillFrontmatter.parse(markdown);
        final directoryName = entry.key == '.'
            ? null
            : p.posix.basename(entry.key);
        final filePaths = <String>[];
        var fileCount = 0;
        await for (final entity in folder.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          fileCount++;
          filePaths.add(
            p.relative(entity.path, from: folder.path).replaceAll('\\', '/'),
          );
        }
        final compatibility = SkillCompatibilityAnalyzer.analyze(
          parsed,
          directoryName: directoryName,
          files: filePaths,
        );
        candidates.add(
          SkillImportCandidate(
            path: entry.key,
            name: parsed.name.isEmpty ? entry.key : parsed.name,
            description: parsed.description,
            bodyPreview: parsed.body.trim().substring(
              0,
              parsed.body.trim().length > 1200 ? 1200 : parsed.body.trim().length,
            ),
            license: parsed.license,
            environmentCompatibility: parsed.compatibility,
            metadata: Map.unmodifiable(parsed.metadata),
            allowedTools: parsed.allowedTools,
            fileCount: fileCount,
            sharedFileCount: sharedPaths.length,
            sharedBytes: sharedFileBytes,
            compatibility: compatibility,
          ),
        );
        candidateFolders[entry.key] = folder;
      }
      candidates.sort((a, b) => a.path.compareTo(b.path));
      if (candidates.isEmpty) {
        throw const FormatException('no_agent_skills_found');
      }
      final selected = await chooseSkills(List.unmodifiable(candidates));
      checkCancelled();
      if (selected == null || selected.isEmpty) return const <Skill>[];
      final byPath = <String, SkillImportCandidate>{
        for (final candidate in candidates) candidate.path: candidate,
      };
      if (selected.any((path) => !byPath.containsKey(path))) {
        throw const FormatException('invalid_skill_selection');
      }
      final invalid = selected
          .map((path) => byPath[path]!)
          .where((candidate) => !candidate.compatibility.isImportable)
          .toList();
      if (invalid.isNotEmpty) {
        throw FormatException(
          'Selected Skill is not Agent Skills compatible: '
          '${invalid.map((candidate) => '${candidate.path}: '
              '${candidate.compatibility.errors.join('; ')}').join(' | ')}',
        );
      }

      final commit = await _resolveGitHubCommitSha(ref, revision);
      final sharedBundle = await _persistRepositorySharedResources(
        sourceDirectory: sharedDirectory,
        paths: sharedPaths,
        repository: '${ref.owner}/${ref.repo}',
        ref: ref.ref ?? revision,
        commit: commit,
      );
      final skipped = _skippedEntries(extraction['skipped']);
      onProgress?.call(const SkillImportProgress(SkillImportPhase.installing));
      final result = await _serializeMutation(() async {
        final imported = <Skill>[];
        try {
          for (final path in selected) {
            checkCancelled();
            final parsed = SkillFrontmatter.parse(
              await File(p.join(candidateFolders[path]!.path, 'SKILL.md'))
                  .readAsString(),
            );
            final id = await _allocateId(slugify(parsed.name));
            final destination = Directory(p.join(root.path, id));
            await candidateFolders[path]!.rename(destination.path);
            installedIds.add(id);
            final skill = await _registerImport(
              root, id, SkillSource.github, writeDefaultImportManifest: false,
            );
            final sourceSubpath = path == '.' ? ref.subdir : path;
            await _writeSkillImportManifest(
              skillId: id,
              skillDirectory: destination,
              sourceType: SkillSource.github.name,
              sourceUrl: _canonicalGitHubSkillSource(
                ref.copyWith(subdir: sourceSubpath), revision,
              ),
              repository: '${ref.owner}/${ref.repo}',
              ref: ref.ref ?? revision,
              commit: commit,
              sharedDirectory: sharedBundle?.directory,
              sharedResourceSetId: sharedBundle?.id,
              sharedResourcePaths: sharedPaths,
              skipped: skipped,
              executableOverrides: _skillModeMap(
                extraction['skillExecutableModes'], path,
              ),
              sharedExecutableOverrides: _stringBoolMap(
                extraction['sharedExecutableModes'],
              ),
              completeness: skipped.isEmpty ? 'complete' : 'partial',
              completenessNotes: skipped.isEmpty ? const [] : const [
                'One or more symbolic links were not imported.',
              ],
            );
            // Candidate paths are already repository-relative and include the
            // selected source subdirectory. Do not prepend ref.subdir twice.
            await _syncSkillExtension(
              skill,
              sourceUri: _canonicalGitHubSkillSource(
                ref.copyWith(subdir: sourceSubpath),
                revision,
              ),
              sourceRef: ref.ref ?? revision,
              sourceSubpath: sourceSubpath,
              sourceRevision: revision,
            );
            imported.add(skill);
          }
          return List<Skill>.unmodifiable(imported);
        } catch (_) {
          for (final id in installedIds) {
            await store.delete(ExtensionEntityStore.kindSkill, id);
            await _extensionRegistry.remove('skill', id);
            await _deleteSkillImportManifest(id);
            final directory = Directory(p.join(root.path, id));
            if (await directory.exists()) {
              await directory.delete(recursive: true);
            }
            _skills.removeWhere((skill) => skill.record.id == id);
          }
          if (sharedBundle != null && await sharedBundle.directory.parent.exists()) {
            await sharedBundle.directory.parent.delete(recursive: true);
          }
          notifyListeners();
          rethrow;
        }
      });
      if (result.isNotEmpty) {
        await _serializeMutation(() async {
          await _loadSkillPacksAndDetectRepositories(_skills);
          if (!_disposed) notifyListeners();
        });
      }
      return result;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Inspect all Skills in a GitHub repository/subfolder without installing
  /// them or running their files. The legacy preview keys remain available for
  /// a single Skill so older callers keep working.
  Future<Map<String, Object?>> inspectGitHubSkill(
    String url, {
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    var cancelled = false;
    unawaited(
      cancelSignal?.then<void>((_) {
        cancelled = true;
      }),
    );
    void checkCancelled() {
      if (cancelled) throw http.RequestAbortedException();
    }

    final ref = GitHubSkillRef.parse(url);
    final revision = await _resolveGitHubRef(ref, cancelSignal: cancelSignal);
    checkCancelled();
    final root = await _ensureRoot();
    final staging = await root.createTemp('.inspect-');
    try {
      final zip = File(p.join(staging.path, 'download.zip'));
      await _downloadGitHubZip(ref, revision, zip, cancelSignal: cancelSignal);
      checkCancelled();
      if (ref.filePath != null) {
        final directFile = File(p.join(
          staging.path,
          'source-${p.posix.basename(ref.filePath!)}',
        ));
        await compute(_extractGitHubRepositoryFile, (
          zip.path,
          directFile.path,
          ref.filePath!,
          true,
        ));
        final preview = await inspectLocalSource(directFile.path);
        return <String, Object?>{
          ...preview,
          'source': url,
          'resolvedRef': revision,
          'resolvedCommit': await _resolveGitHubCommitSha(ref, revision),
          'sourceFile': ref.filePath,
          'scriptsAreNotExecuted': true,
        };
      }
      final extracted = Directory(p.join(staging.path, 'files'));
      final extraction = await compute(_extractRepositoryArchive, (
        zip.path,
        extracted.path,
        ref.subdir,
        true,
      ));
      final folders = _stringMap(extraction['skills']);
      final sharedPaths = (extraction['sharedPaths'] as List? ?? const [])
          .whereType<String>().toList(growable: false);
      final sharedDirectoryName = extraction['sharedDirectory'] as String?;
      final sharedBytes = await _directoryFileBytes(sharedDirectoryName == null
          ? null : Directory(p.join(extracted.path, sharedDirectoryName)));
      final candidates = <Map<String, Object?>>[];
      for (final entry in folders.entries) {
        checkCancelled();
        final folder = Directory(p.join(extracted.path, entry.value));
        final markdown = await File(p.join(folder.path, 'SKILL.md'))
            .readAsString();
        final parsed = SkillFrontmatter.parse(markdown);
        final paths = <String>[];
        var scriptCount = 0;
        var totalBytes = 0;
        await for (final entity in folder.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          final relative = p.relative(entity.path, from: folder.path)
              .replaceAll('\\', '/');
          paths.add(relative);
          totalBytes += await entity.length();
          if (const {'.sh', '.py', '.js', '.mjs', '.cjs', '.ts', '.rb', '.pl'}
              .contains(p.extension(relative).toLowerCase())) {
            scriptCount++;
          }
        }
        final directoryName = entry.key == '.'
            ? null
            : p.posix.basename(entry.key);
        final compatibility = SkillCompatibilityAnalyzer.analyze(
          parsed,
          directoryName: directoryName,
          files: paths,
        );
        final body = parsed.body.trim();
        candidates.add(<String, Object?>{
          'path': entry.key,
          'name': parsed.name,
          'description': parsed.description,
          'license': parsed.license,
          'compatibilityRequirements': parsed.compatibility,
          'metadata': parsed.metadata,
          'allowedToolsHint': parsed.allowedTools,
          'fileCount': paths.length,
          'sharedFileCount': sharedPaths.length,
          'sharedBytes': sharedBytes,
          'scriptCount': scriptCount,
          'sizeBytes': totalBytes,
          'hasScripts': scriptCount > 0,
          'scriptsAreNotExecuted': true,
          'compatibility': compatibility.toJson(),
          'bodyPreview': body.substring(0, body.length > 4000 ? 4000 : body.length),
        });
      }
      candidates.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
      if (candidates.length == 1) {
        return <String, Object?>{
          ...candidates.single,
          'source': url,
          'resolvedRef': revision,
          'resolvedCommit': await _resolveGitHubCommitSha(ref, revision),
          'subpath': ref.subdir,
          'sharedFileCount': sharedPaths.length,
          'sharedBytes': sharedBytes,
          'skipped': extraction['skipped'],
          'candidates': candidates,
        };
      }
      return <String, Object?>{
        'source': url,
        'resolvedRef': revision,
        'resolvedCommit': await _resolveGitHubCommitSha(ref, revision),
        'subpath': ref.subdir,
        'sharedFileCount': sharedPaths.length,
        'sharedBytes': sharedBytes,
        'skipped': extraction['skipped'],
        'skillCount': candidates.length,
        'scriptsAreNotExecuted': true,
        'candidates': candidates,
      };
    } finally {
      await staging.delete(recursive: true);
    }
  }

  /// Update an existing GitHub Skill in place. The currently installed
  /// revision is snapshotted before replacement so [rollback] can restore it.
  Future<Skill> updateFromGitHub(
    String id,
    String url, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    var cancelled = false;
    unawaited(
      cancelSignal?.then<void>((_) {
        cancelled = true;
      }),
    );
    void checkCancelled() {
      if (cancelled) throw http.RequestAbortedException();
    }

    final ref = GitHubSkillRef.parse(url);
    if (ref.filePath != null) {
      throw const FormatException(
        'Direct GitHub .skill/.zip file sources can be imported and inspected, '
        'but automatic in-place updates require a repository or Skill-folder URL.',
      );
    }
    onProgress?.call(const SkillImportProgress(SkillImportPhase.resolving));
    final branch = await _resolveGitHubRef(ref, cancelSignal: cancelSignal);
    final commit = await _resolveGitHubCommitSha(ref, branch);
    final root = await _ensureRoot();
    final staging = await root.createTemp('.update-');
    try {
      final zip = File(p.join(staging.path, 'download.zip'));
      await _downloadGitHubZip(
        ref,
        branch,
        zip,
        onProgress: onProgress,
        cancelSignal: cancelSignal,
      );
      checkCancelled();
      final extracted = Directory(p.join(staging.path, 'files'));
      onProgress?.call(const SkillImportProgress(SkillImportPhase.extracting));
      final archiveDirectoryName = await compute(_extractArchive, (
        zip.path,
        extracted.path,
        ref.subdir,
        true,
      ));
      checkCancelled();
      final markdown = await File(
        p.join(extracted.path, 'SKILL.md'),
      ).readAsString();
      final parsed = SkillFrontmatter.parse(markdown);
      final errors = parsed.validate(directoryName: archiveDirectoryName);
      if (errors.isNotEmpty) {
        throw FormatException('Invalid SKILL.md: ${errors.join(', ')}');
      }
      onProgress?.call(const SkillImportProgress(SkillImportPhase.installing));
      return await _serializeMutation(() async {
        checkCancelled();
        final current = _require(id);
        final destination = Directory(p.join(root.path, id));
        final hold = Directory(p.join(staging.path, 'previous-current'));
        await _snapshotSkillVersion(current);
        await destination.rename(hold.path);
        try {
          await extracted.rename(destination.path);
          final now = DateTime.now().toUtc();
          final next = current.record.copyWith(
            source: SkillSource.github,
            updatedAt: now,
          );
          await _upsertRecord(next);
          final updated = await _skillFromDisk(root, next);
          _skills[_skills.indexWhere((item) => item.record.id == id)] = updated;
          await _syncSkillExtension(
            updated,
            sourceUri: _canonicalGitHubSkillSource(ref, branch),
            sourceRef: ref.ref ?? branch,
            sourceSubpath: ref.subdir,
            sourceRevision: branch,
          );
          await _refreshSkillImportManifestAfterUpdate(
            skillId: id,
            sourceType: SkillSource.github.name,
            sourceUrl: _canonicalGitHubSkillSource(ref, branch),
            repository: '${ref.owner}/${ref.repo}',
            ref: ref.ref ?? branch,
            commit: commit,
            completenessNote: 'The legacy single-Skill updater refreshes the selected Skill directory only; existing repository-shared resources are retained from the previous import snapshot and are not refreshed here.',
          );
          notifyListeners();
          return updated;
        } catch (_) {
          final failedDestination = Directory(destination.path);
          if (await failedDestination.exists()) {
            await failedDestination.delete(recursive: true);
          }
          if (await hold.exists()) await hold.rename(destination.path);
          try {
            await _upsertRecord(current.record);
            final restoredCurrent = await _skillFromDisk(root, current.record);
            final index = _skills.indexWhere((item) => item.record.id == id);
            if (index >= 0) _skills[index] = restoredCurrent;
            await _restoreLatestSkillImportManifest(id);
          } catch (_) {}
          rethrow;
        }
      });
    } finally {
      await staging.delete(recursive: true);
    }
  }

  /// Restore the most recent pre-update Skill snapshot.
  Future<Skill> rollback(String id) async {
    await loaded;
    return _serializeMutation(() async {
      final current = _require(id);
      final root = await _ensureRoot();
      final versions = Directory(p.join(root.path, '.versions', id));
      if (!await versions.exists()) {
        throw StateError('No rollback snapshot exists for Skill $id.');
      }
      final snapshots = <Directory>[];
      await for (final entity in versions.list(followLinks: false)) {
        if (entity is Directory &&
            await File(p.join(entity.path, 'manifest.json')).exists() &&
            await Directory(p.join(entity.path, 'files')).exists()) {
          snapshots.add(entity);
        }
      }
      if (snapshots.isEmpty) {
        throw StateError('No valid rollback snapshot exists for Skill $id.');
      }
      snapshots.sort(
        (a, b) => p.basename(b.path).compareTo(p.basename(a.path)),
      );
      final selected = snapshots.first;
      final manifest = jsonDecode(
        await File(p.join(selected.path, 'manifest.json')).readAsString(),
      );
      if (manifest is! Map || manifest['skillRecord'] is! Map) {
        throw const FormatException('invalid_skill_rollback_manifest');
      }
      final restoredRecord = SkillRecord.fromJson(
        Map<String, dynamic>.from(manifest['skillRecord'] as Map),
      );
      if (restoredRecord.id != id) {
        throw const FormatException('skill_rollback_identity');
      }
      // Save the current version too, allowing the user to toggle back.
      await _snapshotSkillVersion(current);
      final restoreStage = await root.createTemp('.rollback-');
      try {
        final replacement = Directory(p.join(restoreStage.path, 'files'));
        await _copySkillDirectory(
          Directory(p.join(selected.path, 'files')),
          replacement,
        );
        final destination = Directory(p.join(root.path, id));
        final hold = Directory(p.join(restoreStage.path, 'current'));
        await destination.rename(hold.path);
        try {
          await replacement.rename(destination.path);
          await _upsertRecord(restoredRecord);
          final rawExtension = manifest['extensionRecord'];
          if (rawExtension is Map) {
            await _extensionRegistry.upsert(
              ExtensionRecord.fromJson(Map<String, dynamic>.from(rawExtension)),
            );
          }
          await _restoreSkillImportManifestSnapshot(id, selected);
          final restored = await _skillFromDisk(root, restoredRecord);
          final index = _skills.indexWhere((item) => item.record.id == id);
          if (index >= 0) {
            _skills[index] = restored;
          } else {
            _skills.add(restored);
          }
          _skills.sort((a, b) => a.record.id.compareTo(b.record.id));
          notifyListeners();
          return restored;
        } catch (_) {
          final failedDestination = Directory(destination.path);
          if (await failedDestination.exists()) {
            await failedDestination.delete(recursive: true);
          }
          if (await hold.exists()) await hold.rename(destination.path);
          await _restoreLatestSkillImportManifest(id);
          rethrow;
        }
      } finally {
        await restoreStage.delete(recursive: true);
      }
    });
  }

  Future<Map<String, Object?>> inspectLocalSource(String path) async {
    await loaded;
    final entityType = await FileSystemEntity.type(path, followLinks: false);
    if (entityType == FileSystemEntityType.directory) {
      final md = File(p.join(path, 'SKILL.md'));
      if (!await md.exists()) {
        throw const FormatException('SKILL.md not found');
      }
      final markdown = await md.readAsString();
      final parsed = SkillFrontmatter.parse(markdown);
      final directoryName = p.basename(p.normalize(path));
      final errors = parsed.validate(directoryName: directoryName);
      if (errors.isNotEmpty) throw FormatException(errors.join(', '));
      final paths = <String>[];
      await for (final entity in Directory(path).list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        paths.add(p.relative(entity.path, from: path).replaceAll('\\', '/'));
      }
      return _localSkillPreview(
        parsed: parsed,
        source: path,
        filePaths: paths,
        directoryName: directoryName,
      );
    }

    final file = File(path);
    if (!await file.exists()) throw FileSystemException('Source not found', path);
    final extension = p.extension(path).toLowerCase();
    final signatureFile = await file.open();
    List<int> signature;
    try {
      signature = await signatureFile.read(4);
    } finally {
      await signatureFile.close();
    }
    final isZipPayload = signature.length >= 2 &&
        signature[0] == 0x50 && signature[1] == 0x4b;
    if (extension == '.md' || (extension == '.skill' && !isZipPayload)) {
      final parsed = SkillFrontmatter.parse(await file.readAsString());
      final errors = parsed.validate();
      if (errors.isNotEmpty) throw FormatException(errors.join(', '));
      return _localSkillPreview(
        parsed: parsed,
        source: path,
        filePaths: const <String>['SKILL.md'],
      );
    }
    if (extension != '.zip' && extension != '.skill') {
      throw const FormatException(
        'Supported local sources are a Skill folder, Markdown .skill/.md file, or ZIP.',
      );
    }

    final root = await _ensureRoot();
    final staging = await root.createTemp('.inspect-');
    try {
      late Directory extracted;
      late Map<String, Object?> extraction;
      extracted = Directory(p.join(staging.path, 'repository'));
      try {
        extraction = await compute(_extractRepositoryArchive, (
          path,
          extracted.path,
          null,
          false,
        ));
      } on FormatException catch (error) {
        if (!error.message.toString().contains('SKILL.md not found')) rethrow;
        extracted = Directory(p.join(staging.path, 'nested-bundle'));
        extraction = await compute(_extractNestedSkillBundle, (
          path,
          extracted.path,
        ));
      }
      final folders = _stringMap(extraction['skills']);
      final sharedPaths = (extraction['sharedPaths'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false);
      final sharedName = extraction['sharedDirectory'] as String?;
      final sharedBytes = await _directoryFileBytes(
        sharedName == null ? null : Directory(p.join(extracted.path, sharedName)),
      );
      final candidates = <Map<String, Object?>>[];
      for (final entry in folders.entries) {
        final folder = Directory(p.join(extracted.path, entry.value));
        final markdownFile = File(p.join(folder.path, 'SKILL.md'));
        if (!await markdownFile.exists()) continue;
        final parsed = SkillFrontmatter.parse(await markdownFile.readAsString());
        final paths = <String>[];
        await for (final entity in folder.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          paths.add(p.relative(entity.path, from: folder.path).replaceAll('\\', '/'));
        }
        candidates.add(<String, Object?>{
          ..._localSkillPreview(
            parsed: parsed,
            source: path,
            filePaths: paths,
            directoryName: entry.key == '.' ? null : p.posix.basename(entry.key),
          ),
          'path': entry.key,
          'sharedFileCount': sharedPaths.length,
          'sharedBytes': sharedBytes,
        });
      }
      candidates.sort((a, b) =>
          (a['path'] as String).compareTo(b['path'] as String));
      if (candidates.isEmpty) {
        throw const FormatException('no_agent_skills_found');
      }
      if (candidates.length == 1) {
        return <String, Object?>{
          ...candidates.single,
          'skillCount': 1,
          'candidates': candidates,
          'scriptsAreNotExecuted': true,
          'skipped': extraction['skipped'],
        };
      }
      return <String, Object?>{
        'source': path,
        'skillCount': candidates.length,
        'sharedFileCount': sharedPaths.length,
        'sharedBytes': sharedBytes,
        'scriptsAreNotExecuted': true,
        'candidates': candidates,
        'skipped': extraction['skipped'],
      };
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Map<String, Object?> _localSkillPreview({
    required SkillFrontmatter parsed,
    required String source,
    required List<String> filePaths,
    String? directoryName,
  }) {
    final compatibility = SkillCompatibilityAnalyzer.analyze(
      parsed,
      directoryName: directoryName,
      files: filePaths,
    );
    final scriptCount = filePaths.where(_isSkillScript).length;
    final body = parsed.body.trim();
    return <String, Object?>{
      'name': parsed.name,
      'description': parsed.description,
      'license': parsed.license,
      'compatibilityRequirements': parsed.compatibility,
      'metadata': parsed.metadata,
      'allowedToolsHint': parsed.allowedTools,
      'source': source,
      'fileCount': filePaths.length,
      'scriptCount': scriptCount,
      'hasScripts': scriptCount > 0,
      'scriptsAreNotExecuted': true,
      'compatibility': compatibility.toJson(),
      'bodyPreview': body.substring(0, body.length > 4000 ? 4000 : body.length),
    };
  }

  static bool _isSkillScript(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').contains('scripts') ||
        const {
          '.sh', '.py', '.js', '.mjs', '.cjs', '.ts', '.rb', '.pl',
        }.contains(p.extension(normalized).toLowerCase());
  }

  Future<String> readSkillMarkdown(
    String id, {
    int maxCharacters = 24000,
  }) async {
    await loaded;
    final skill = _require(id);
    final markdown = await File(skill.skillMdPath).readAsString();
    if (markdown.length <= maxCharacters) return markdown;
    return '${markdown.substring(0, maxCharacters)}\n\n'
        '[Skill instructions truncated by Kelivo inspection limit.]';
  }

  /// Reads only the leading YAML frontmatter for metadata-first Skill planning.
  Future<String> readSkillFrontmatterMarkdown(
    String id, {
    int maxBytes = 64 * 1024,
  }) async {
    await loaded;
    final skill = _require(id);
    return SkillFrontmatter.readHeader(
      File(skill.skillMdPath),
      maxBytes: maxBytes,
    );
  }

  List<Skill> searchInstalled(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return List.unmodifiable(_skills);
    return List.unmodifiable(
      _skills.where(
        (skill) =>
            skill.record.id.toLowerCase().contains(normalized) ||
            skill.name.toLowerCase().contains(normalized) ||
            skill.description.toLowerCase().contains(normalized),
      ),
    );
  }

  bool hasRollback(String id) {
    final root = _skillsDirectory ?? _injectedSkillsDirectory;
    if (root == null) return false;
    return Directory(p.join(root.path, '.versions', id)).existsSync();
  }

  Future<Skill> importFromGitHub(
    String url, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    var cancelled = false;
    unawaited(
      cancelSignal?.then<void>((_) {
        cancelled = true;
      }),
    );
    void checkCancelled() {
      if (cancelled) throw http.RequestAbortedException();
    }

    await loaded;
    checkCancelled();
    final ref = GitHubSkillRef.parse(url);
    onProgress?.call(const SkillImportProgress(SkillImportPhase.resolving));
    final branch = await _resolveGitHubRef(ref, cancelSignal: cancelSignal);
    checkCancelled();
    final root = await _ensureRoot();
    final staging = await root.createTemp('.import-');
    try {
      final zip = File(p.join(staging.path, 'download.zip'));
      await _downloadGitHubZip(
        ref,
        branch,
        zip,
        onProgress: onProgress,
        cancelSignal: cancelSignal,
      );
      checkCancelled();
      final installed = await _importArchive(
        zip,
        staging,
        SkillSource.github,
        subdir: ref.subdir,
        stripSingleRoot: true,
        onProgress: onProgress,
        checkCancelled: checkCancelled,
      );
      await _syncSkillExtension(
        installed,
        sourceUri: _canonicalGitHubSkillSource(ref, branch),
        sourceRef: ref.ref ?? branch,
        sourceSubpath: ref.subdir,
        sourceRevision: branch,
      );
      await _loadSkillPacksAndDetectRepositories(_skills);
      if (!_disposed) notifyListeners();
      return installed;
    } finally {
      await staging.delete(recursive: true);
    }
  }

  Future<Skill> _importArchive(
    File zip,
    Directory staging,
    SkillSource source, {
    String? subdir,
    bool stripSingleRoot = false,
    ValueChanged<SkillImportProgress>? onProgress,
    FutureOr<void> Function()? checkCancelled,
  }) async {
    onProgress?.call(const SkillImportProgress(SkillImportPhase.extracting));
    final extracted = Directory(p.join(staging.path, 'files'));
    final extraction = await compute(_extractRepositoryArchive, (
      zip.path, extracted.path, subdir, stripSingleRoot,
    ));
    await checkCancelled?.call();
    final folders = _stringMap(extraction['skills']);
    if (folders.length != 1) {
      throw FormatException(
        'multiple_skills_found_in_local_archive:${folders.keys.join(',')}',
      );
    }
    final skillEntry = folders.entries.single;
    final skillDirectory = Directory(p.join(extracted.path, skillEntry.value));
    final parsed = SkillFrontmatter.parse(
      await File(p.join(skillDirectory.path, 'SKILL.md')).readAsString(),
    );
    final directoryName = skillEntry.key == '.'
        ? null : p.posix.basename(skillEntry.key);
    final errors = parsed.validate(directoryName: directoryName);
    if (errors.isNotEmpty) {
      throw FormatException('Invalid SKILL.md: ${errors.join(', ')}');
    }
    final sharedName = extraction['sharedDirectory'] as String?;
    final sharedPaths = (extraction['sharedPaths'] as List? ?? const [])
        .whereType<String>().toList(growable: false);
    final sharedBundle = await _persistRepositorySharedResources(
      sourceDirectory: sharedName == null
          ? null : Directory(p.join(extracted.path, sharedName)),
      paths: sharedPaths,
      repository: 'local-archive:${p.basename(zip.path)}',
      ref: 'local',
      commit: null,
    );
    onProgress?.call(const SkillImportProgress(SkillImportPhase.installing));
    return _serializeMutation(() async {
      final root = await _ensureRoot();
      String? allocatedSkillId;
      Directory? destinationDirectory;
      try {
        final id = await _allocateId(slugify(parsed.name));
        allocatedSkillId = id;
        final destination = Directory(p.join(root.path, id));
        destinationDirectory = destination;
        await checkCancelled?.call();
        await skillDirectory.rename(destination.path);
        await checkCancelled?.call();
        final skill = await _registerImport(
          root, id, source, writeDefaultImportManifest: false,
        );
        final skipped = _skippedEntries(extraction['skipped']);
        await _writeSkillImportManifest(
          skillId: id,
          skillDirectory: destination,
          sourceType: source.name,
          sharedDirectory: sharedBundle?.directory,
          sharedResourceSetId: sharedBundle?.id,
          sharedResourcePaths: sharedPaths,
          skipped: skipped,
          executableOverrides: _skillModeMap(extraction['skillExecutableModes'], skillEntry.key),
          sharedExecutableOverrides: _stringBoolMap(extraction['sharedExecutableModes']),
          completeness: skipped.isEmpty ? 'complete' : 'partial',
          completenessNotes: skipped.isEmpty ? const [] : const [
            'One or more symbolic links were not imported.',
          ],
        );
        return skill;
      } catch (_) {
        final id = allocatedSkillId;
        if (id != null) {
          await store.delete(ExtensionEntityStore.kindSkill, id);
          await _extensionRegistry.remove('skill', id);
          await _deleteSkillImportManifest(id);
          _skills.removeWhere((item) => item.record.id == id);
        }
        final destination = destinationDirectory;
        if (destination != null && await destination.exists()) {
          await destination.delete(recursive: true);
        }
        if (sharedBundle != null && await sharedBundle.directory.parent.exists()) {
          await sharedBundle.directory.parent.delete(recursive: true);
        }
        rethrow;
      }
    });
  }

  static String? _extractArchive((String, String, String?, bool) args) {
    return extractSkillArchive(
      args.$1,
      args.$2,
      subdir: args.$3,
      stripSingleRoot: args.$4,
    );
  }

  Future<File> exportZip(String id, Directory outDir) async {
    await loaded;
    final skill = _require(id);
    final files = <String, List<int>>{};
    final dir = Directory(skill.dir);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = p
          .relative(entity.path, from: skill.dir)
          .replaceAll('\\', '/');
      if (rel.split('/').contains('..')) {
        throw const FormatException('zip-slip');
      }
      files[rel] = await entity.readAsBytes();
    }
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    final out = File(p.join(outDir.path, '$id.zip'));
    await out.writeAsBytes(encodeSkillZip(files), flush: true);
    return out;
  }

  Future<void> delete(String id) async {
    await loaded;
    await _serializeMutation(() async {
      await store.delete(ExtensionEntityStore.kindSkill, id);
      await _extensionRegistry.remove('skill', id);
      _skillExtensionRecords.remove(id);
      final root = await _ensureRoot();
      final dir = Directory(p.join(root.path, id));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await _deleteSkillImportManifest(id);
      final versions = Directory(p.join(root.path, '.versions', id));
      if (await versions.exists()) await versions.delete(recursive: true);
      _skills.removeWhere((skill) => skill.record.id == id);
      for (var index = _skillPacks.length - 1; index >= 0; index--) {
        final pack = _skillPacks[index];
        if (!pack.skillIds.contains(id)) continue;
        final remaining = pack.skillIds.where((member) => member != id).toList();
        if (remaining.isEmpty) {
          await store.delete(ExtensionEntityStore.kindSkillPack, pack.id);
          _skillPacks.removeAt(index);
        } else {
          final nextPack = pack.copyWith(
            skillIds: remaining,
            updatedAt: DateTime.now().toUtc(),
            autoDetected: false,
          );
          await store.upsert(
            ExtensionEntityStore.kindSkillPack,
            nextPack.id,
            nextPack.toJson(),
            sortOrder: index,
          );
          _skillPacks[index] = nextPack;
        }
      }
      notifyListeners();
    });
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await loaded;
    // A Skill's standalone availability is independent from every pack that
    // references it. Pack activation is stored only on the pack record.
    await _serializeMutation(() async {
      final skill = _require(id);
      final next = skill.record.copyWith(
        enabled: enabled,
        updatedAt: DateTime.now().toUtc(),
      );
      await _upsertRecord(next);
      _replace(skill, record: next);
      notifyListeners();
    });
  }

  Future<void> incrementUseCount(String id) async {
    try {
      await loaded;
      await _serializeMutation(() async {
        final index = _skills.indexWhere((skill) => skill.record.id == id);
        if (index < 0) return;
        final skill = _skills[index];
        final next = skill.record.copyWith(
          useCount: skill.record.useCount + 1,
          updatedAt: DateTime.now().toUtc(),
        );
        await _upsertRecord(next);
        _skills[index] = Skill(
          record: next,
          name: skill.name,
          description: skill.description,
          dir: skill.dir,
          skillMdPath: skill.skillMdPath,
        );
        notifyListeners();
      });
    } catch (e) {
      debugPrint('incrementUseCount failed: $e');
    }
  }

  Future<void> updateBody(String id, String markdown) async {
    await loaded;
    await _serializeMutation(() async {
      final skill = _require(id);
      final parsed = SkillFrontmatter.parse(markdown);
      await File(skill.skillMdPath).writeAsString(markdown, flush: true);
      final next = skill.record.copyWith(updatedAt: DateTime.now().toUtc());
      await _upsertRecord(next);
      // Editing SKILL.md changes the analyzed source. Drop its requirement
      // inventory and validation snapshot so the next inspect must re-hash
      // and re-analyze the installed files before any readiness claim.
      final metadataRoot = await _ensureSkillImportMetadataRoot();
      final reportFile = File(p.join(metadataRoot.path, 'skills', '$id.json'));
      if (await reportFile.exists()) {
        final decoded = jsonDecode(await reportFile.readAsString());
        if (decoded is Map) {
          final invalidated = Map<String, Object?>.from(decoded)
            ..remove('environmentAssessment')
            ..remove('requirements')
            ..remove('requirementInventorySourceDigest')
            ..remove('sourceDigest')
            ..['readinessInvalidatedAt'] = DateTime.now().toUtc().toIso8601String();
          final temporary = File('${reportFile.path}.body-edit.tmp');
          await temporary.writeAsString(
            const JsonEncoder.withIndent('  ').convert(invalidated),
            flush: true,
          );
          if (await reportFile.exists()) await reportFile.delete();
          await temporary.rename(reportFile.path);
        }
      }
      _replace(
        skill,
        record: next,
        name: parsed.name.trim().isEmpty ? skill.name : parsed.name.trim(),
        description: parsed.description,
      );
      notifyListeners();
    });
  }

  Future<void> _loadSkillPacksAndDetectRepositories(
    List<Skill> installed,
  ) async {
    final installedIds = installed.map((skill) => skill.record.id).toSet();
    final rows = await store.listByKind(ExtensionEntityStore.kindSkillPack);
    final packs = <String, SkillPack>{};
    for (final row in rows) {
      try {
        final parsed = SkillPack.fromJson(row.payload);
        final members = parsed.skillIds
            .where(installedIds.contains)
            .toList(growable: false);
        if (members.isEmpty) {
          await store.delete(ExtensionEntityStore.kindSkillPack, parsed.id);
          continue;
        }
        final pack = members.length == parsed.skillIds.length
            ? parsed
            : parsed.copyWith(skillIds: members, updatedAt: DateTime.now().toUtc());
        packs[pack.id] = pack;
        if (pack != parsed) {
          await store.upsert(
            ExtensionEntityStore.kindSkillPack,
            pack.id,
            pack.toJson(),
            sortOrder: row.sortOrder,
          );
        }
      } catch (error) {
        debugPrint('Ignoring invalid Skill Pack ${row.id}: $error');
        await store.delete(ExtensionEntityStore.kindSkillPack, row.id);
      }
    }

    // Repository packs are update/source groupings, not exclusive owners.
    // A Skill may also appear in one or more user-created packs while remaining
    // independently installed, enabled, selectable and executable.
    // Skills imported from one GitHub repository are one logical toolkit even
    // though every folder remains an independent, standards-compliant Skill.
    final repositories = <String, ({String owner, String repo, String family, List<String> ids})>{};
    for (final skill in installed) {
      final record = await _extensionRegistry.get('skill', skill.record.id);
      if (record == null) {
        _skillExtensionRecords.remove(skill.record.id);
        continue;
      }
      _skillExtensionRecords[skill.record.id] = record;
      late final String owner;
      late final String repo;
      String family;
      if (record.source.type == 'skills_sh') {
        final catalogId = _catalogSkillId(record);
        if (catalogId == null) continue;
        final segments = catalogId.split('/');
        if (segments.length < 2 || segments[0].isEmpty || segments[1].isEmpty) {
          continue;
        }
        owner = segments[0];
        repo = segments[1];
        family = 'skills-sh';
      } else {
        final source = record.source.uri;
        if (source == null) continue;
        final parsed = GitHubSkillRef.tryParse(source);
        if (parsed == null) continue;
        final ref = GitHubSkillRef(
          owner: parsed.owner,
          repo: parsed.repo,
          ref: parsed.ref ?? record.source.ref ?? record.source.revision,
          subdir: parsed.subdir ?? record.source.subpath,
        );
        owner = ref.owner;
        repo = ref.repo;
        family = 'github';
      }
      final key = '$family:${owner.toLowerCase()}/${repo.toLowerCase()}';
      final group = repositories.putIfAbsent(
        key,
        () => (owner: owner, repo: repo, family: family, ids: <String>[]),
      );
      group.ids.add(skill.record.id);
    }

    for (final entry in repositories.entries) {
      final generatedId = _repositoryPackId(
        entry.value.owner,
        entry.value.repo,
        sourceFamily: entry.value.family,
      );
      final existing = packs[generatedId];
      final ids = entry.value.ids.toSet().toList();
      if (existing != null) {
        final previousOrder = existing.skillIds;
        ids.sort((a, b) {
          final ai = previousOrder.indexOf(a);
          final bi = previousOrder.indexOf(b);
          if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
          if (ai >= 0) return -1;
          if (bi >= 0) return 1;
          return a.compareTo(b);
        });
      } else {
        ids.sort();
      }
      if (ids.length < 2) {
        if (existing?.autoDetected == true) {
          packs.remove(generatedId);
          await store.delete(ExtensionEntityStore.kindSkillPack, generatedId);
        }
        continue;
      }
      if (existing != null && !existing.autoDetected) continue;
      final now = DateTime.now().toUtc();
      final baseShortcut = slugify(entry.value.repo).replaceAll('-', '_');
      final shortcut = _uniquePackShortcut(
        RegExp(r'^[a-z]').hasMatch(baseShortcut)
            ? baseShortcut
            : 'repo_$baseShortcut',
        exceptId: generatedId,
        packs: packs.values,
      );
      final pack = SkillPack(
        id: generatedId,
        name: _displayRepositoryName(entry.value.repo),
        description: 'Skills imported together from ${entry.value.owner}/${entry.value.repo}.',
        shortcut: existing?.shortcut ?? shortcut,
        skillIds: List.unmodifiable(ids),
        enabled: existing?.enabled ?? false,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        autoDetected: true,
      );
      pack.validate();
      packs[pack.id] = pack;
      final existingRow = rows.where((row) => row.id == pack.id).firstOrNull;
      await store.upsert(
        ExtensionEntityStore.kindSkillPack,
        pack.id,
        pack.toJson(),
        // Keep the user's ordering when a repository pack is rescanned.
        sortOrder: existingRow?.sortOrder ?? rows.length + packs.length,
      );
    }

    _skillPacks
      ..clear()
      ..addAll(packs.values);

    // Do not synchronize pack.enabled back into SkillRecord.enabled.
    // These are independent controls: the pack switch activates its members
    // together, while each original Skill keeps its own standalone state.
  }

  String _repositoryPackId(
    String owner,
    String repo, {
    String sourceFamily = 'github',
  }) {
    // GitHub permits owner and repository names whose combined length can
    // exceed the registry's 128-character key limit. Keep a deterministic
    // repository identity while respecting that storage contract.
    final prefix = sourceFamily == 'skills-sh' ? 'skills-sh' : 'github';
    final raw = '$prefix-${owner.toLowerCase()}-${repo.toLowerCase()}';
    if (raw.length <= 128) return raw;
    var hash = 0x811c9dc5;
    for (final unit in raw.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    final suffix = '-${hash.toRadixString(16).padLeft(8, '0')}';
    return '${raw.substring(0, 128 - suffix.length)}$suffix';
  }

  static bool _isValidCatalogSkillId(String value) {
    final segments = value.split('/');
    return segments.length == 3 &&
        segments.every(
          (segment) =>
              segment.isNotEmpty &&
              segment != '.' &&
              segment != '..' &&
              RegExp(r'^[A-Za-z0-9_.-]{1,100}$').hasMatch(segment),
        );
  }

  String? _catalogSkillId(ExtensionRecord record) {
    final ref = record.source.ref?.trim();
    if (ref != null && _isValidCatalogSkillId(ref)) return ref;
    final raw = record.source.uri;
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'skills.sh' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final value = uri.pathSegments.where((segment) => segment.isNotEmpty).join('/');
    return _isValidCatalogSkillId(value) ? value : null;
  }

  String? _updateFamilyForSkill(String id) {
    final skill = _skills.where((item) => item.record.id == id).firstOrNull;
    final registered = _skillExtensionRecords[id];
    if (skill == null || registered == null) return null;

    // The legacy SkillRecord only identifies the broad source family. A
    // refresh is safe only when the extension registry also contains a
    // validated, replayable origin. This avoids exposing an Update action
    // that can only fail later with the generic `invalid_input` code.
    if (registered.source.type == 'skills_sh') {
      return _catalogSkillId(registered) == null ? null : 'skills-sh';
    }
    if (registered.source.type == SkillSource.github.name) {
      final raw = registered.source.uri;
      final reference = raw == null ? null : GitHubSkillRef.tryParse(raw);
      // A direct .skill/.zip file can be imported, but it is not a complete
      // replayable Skill-folder origin for the in-place directory updater.
      if (reference == null || reference.filePath != null) return null;
      return 'github';
    }
    return null;
  }

  /// Attaches or repairs the remote origin of an installed Skill.
  ///
  /// Accepts a canonical skills.sh Skill URL or a GitHub repository/skill
  /// folder URL. The existing Skill directory and supporting files are never
  /// replaced by this operation; it only records provenance so a later Update
  /// can safely resolve the same source again.
  Future<void> setUpdateSource(String skillId, String rawSource) async {
    await loaded;
    await _serializeMutation(() async {
      final index = _skills.indexWhere((skill) => skill.record.id == skillId);
      if (index < 0) throw StateError('skill_not_found');
      final sourceText = rawSource.trim();
      if (sourceText.isEmpty || sourceText.length > 2048) {
        throw const FormatException('skill_update_source_invalid');
      }

      SkillSource sourceType;
      String sourceUri;
      String? sourceRef;
      String? sourceSubpath;
      String? sourceRevision;
      final candidateUri = Uri.tryParse(
        sourceText.contains('://') ? sourceText : 'https://$sourceText',
      );
      if (candidateUri != null &&
          candidateUri.scheme == 'https' &&
          candidateUri.host.toLowerCase() == 'skills.sh' &&
          !candidateUri.hasQuery &&
          !candidateUri.hasFragment &&
          candidateUri.userInfo.isEmpty &&
          (!candidateUri.hasPort || candidateUri.port == 443)) {
        final catalogId = candidateUri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .join('/');
        if (!_isValidCatalogSkillId(catalogId)) {
          throw const FormatException('skill_update_source_invalid');
        }
        sourceType = SkillSource.skillsSh;
        sourceUri = 'https://skills.sh/$catalogId';
        sourceRef = catalogId;
      } else {
        final ref = GitHubSkillRef.tryParse(sourceText);
        if (ref == null || ref.filePath != null) {
          throw const FormatException(
            'skill_update_source_invalid: use a GitHub repository or Skill-folder URL, not a direct .skill/.zip file URL.',
          );
        }
        sourceType = SkillSource.github;
        final revision = ref.ref ?? 'main';
        sourceUri = _canonicalGitHubSkillSource(ref, revision);
        sourceRef = revision;
        sourceSubpath = ref.subdir;
        sourceRevision = ref.ref;
      }

      final current = _skills[index];
      final nextRecord = current.record.copyWith(
        source: sourceType,
        updatedAt: DateTime.now().toUtc(),
      );
      await store.upsert(
        ExtensionEntityStore.kindSkill,
        skillId,
        nextRecord.toJson(),
      );
      final refreshed = await _skillFromDisk(await _ensureRoot(), nextRecord);
      await _syncSkillExtension(
        refreshed,
        sourceUri: sourceUri,
        sourceRef: sourceRef,
        sourceSubpath: sourceSubpath,
        sourceRevision: sourceRevision,
        replaceSourceMetadata: true,
        rethrowOnFailure: true,
      );
      _replace(current, record: nextRecord);
      await _loadSkillPacksAndDetectRepositories(_skills);
      if (!_disposed) notifyListeners();
    });
  }

  bool canUpdateSkill(String id) => _updateFamilyForSkill(id) != null;

  /// Checks recorded remote origins without writing to installed Skill files.
  /// GitHub checks resolve the latest commit SHA; skills.sh checks compare the
  /// current catalog snapshot hash. Local and legacy sources are reported as
  /// unsupported/unknown rather than guessed to be up to date.
  Future<List<Map<String, Object?>>> checkUpdateAvailability({
    String? skillId,
    bool all = false,
  }) async {
    await loaded;
    final requestedId = skillId?.trim();
    if (!all && (requestedId == null || requestedId.isEmpty)) {
      throw const FormatException('extension_check_updates_requires_id_or_all');
    }
    final selected = all
        ? _skills.take(200).toList(growable: false)
        : _skills.where((item) => item.record.id == requestedId).toList();
    if (selected.isEmpty && !all) {
      throw const FormatException('skill_not_found');
    }

    final results = <Map<String, Object?>>[];
    for (final skill in selected) {
      final id = skill.record.id;
      final registered = await _extensionRegistry.get('skill', id);
      final base = <String, Object?>{
        'id': id,
        'name': skill.name,
        'sourceType': registered?.source.type ?? skill.record.source.name,
        'canUpdate': canUpdateSkill(id),
      };
      if (registered == null) {
        results.add({...base, 'status': 'unknown', 'reason': 'source_metadata_missing'});
        continue;
      }

      try {
        if (registered.source.type == SkillSource.github.name ||
            registered.source.uri?.contains('github.com') == true) {
          final sourceUri = registered.source.uri;
          final parsed = sourceUri == null ? null : GitHubSkillRef.tryParse(sourceUri);
          if (parsed == null) {
            results.add({...base, 'status': 'unsupported', 'reason': 'github_source_unparseable'});
            continue;
          }
          final reference = GitHubSkillRef(
            owner: parsed.owner,
            repo: parsed.repo,
            ref: parsed.ref ?? registered.source.ref ?? registered.source.revision,
            subdir: parsed.subdir ?? registered.source.subpath,
          );
          final recordedRef = reference.ref;
          if (recordedRef != null && RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(recordedRef)) {
            results.add({
              ...base,
              'status': 'pinned',
              'updateAvailable': false,
              'currentRevision': recordedRef.toLowerCase(),
              'reason': 'source_is_pinned_to_commit',
            });
            continue;
          }
          if (recordedRef == null &&
              registered.source.revision != null &&
              RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(registered.source.revision!)) {
            results.add({
              ...base,
              'status': 'pinned',
              'updateAvailable': false,
              'currentRevision': registered.source.revision!.toLowerCase(),
              'reason': 'no_tracking_branch_recorded_commit_revision_is_only_known',
            });
            continue;
          }
          final branch = await _resolveGitHubRef(reference);
          final remoteCommit = await _resolveGitHubCommitSha(reference, branch);
          if (remoteCommit == null) {
            results.add({...base, 'status': 'unknown', 'reason': 'github_remote_revision_unavailable'});
            continue;
          }
          final importReport = await getImportReport(id);
          final rawSource = importReport?['source'];
          final sourceManifest = rawSource is Map
              ? Map<String, Object?>.from(rawSource)
              : const <String, Object?>{};
          final currentCommit = (sourceManifest['commit'] ??
                  (RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(registered.source.revision ?? '')
                      ? registered.source.revision
                      : null))
              ?.toString()
              .toLowerCase();
          if (currentCommit == null ||
              !RegExp(r'^[a-f0-9]{40}$').hasMatch(currentCommit)) {
            results.add({
              ...base,
              'status': 'unknown',
              'remoteRevision': remoteCommit,
              'reason': 'installed_commit_not_recorded',
            });
            continue;
          }
          final updateAvailable = remoteCommit != currentCommit;
          results.add({
            ...base,
            'status': updateAvailable ? 'update_available' : 'up_to_date',
            'updateAvailable': updateAvailable,
            'currentRevision': currentCommit,
            'remoteRevision': remoteCommit,
            'trackingRef': branch,
          });
          continue;
        }

        if (registered.source.type == 'skills_sh') {
          final catalogId = _catalogSkillId(registered);
          if (catalogId == null) {
            results.add({...base, 'status': 'unsupported', 'reason': 'skills_catalog_reference_missing'});
            continue;
          }
          // This is a read-only catalog/API fetch. The returned files remain
          // in memory and are never extracted or committed to the Skills tree.
          final remote = await _skillsCatalogAdapter.resolve(catalogId);
          final remoteRevision = remote.hash;
          final currentRevision = registered.source.revision;
          if (remoteRevision == null || remoteRevision.isEmpty ||
              currentRevision == null || currentRevision.isEmpty) {
            results.add({
              ...base,
              'status': 'unknown',
              'remoteRevision': remoteRevision,
              'currentRevision': currentRevision,
              'reason': 'catalog_revision_unavailable',
            });
            continue;
          }
          final updateAvailable = remoteRevision != currentRevision;
          results.add({
            ...base,
            'status': updateAvailable ? 'update_available' : 'up_to_date',
            'updateAvailable': updateAvailable,
            'currentRevision': currentRevision,
            'remoteRevision': remoteRevision,
            'catalogId': catalogId,
            'transportComplete': remote.transportComplete,
          });
          continue;
        }

        results.add({...base, 'status': 'unsupported', 'reason': 'local_or_untracked_source'});
      } catch (error) {
        final safeError = error.toString().replaceAll(RegExp(r'[\r\n]+'), ' ');
        results.add({
          ...base,
          'status': 'unknown',
          'reason': safeError.length > 220 ? safeError.substring(0, 220) : safeError,
        });
      }
    }
    return List<Map<String, Object?>>.unmodifiable(results);
  }

  bool canUpdateSkillPack(String packId) {
    final pack = _skillPacks.where((item) => item.id == packId).firstOrNull;
    // Only repository-detected groups own a shared upstream revision. A user
    // Pack is an organizational shortcut; its member Skills update alone.
    if (pack == null || !pack.autoDetected || pack.skillIds.isEmpty) return false;
    final families = pack.skillIds.map(_updateFamilyForSkill).toSet();
    return families.length == 1 && !families.contains(null);
  }


  String _displayRepositoryName(String value) {
    final words = value
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'));
    return words
        .where((word) => word.isNotEmpty)
        .map((word) => '${word.substring(0, 1).toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _uniquePackShortcut(
    String requested, {
    String? exceptId,
    Iterable<SkillPack>? packs,
  }) {
    var base = requested.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    if (base.isEmpty || !RegExp(r'^[a-z]').hasMatch(base)) base = 'skills_$base';
    if (base.length > 32) base = base.substring(0, 32);
    final existing = packs ?? _skillPacks;
    var candidate = base;
    var suffix = 2;
    while (existing.any((pack) => pack.id != exceptId && pack.shortcut == candidate)) {
      final tail = '_$suffix';
      candidate = '${base.substring(0, base.length > 32 - tail.length ? 32 - tail.length : base.length)}$tail';
      suffix++;
    }
    return candidate;
  }

  SkillPack? packByShortcut(String shortcut) {
    final normalized = shortcut.trim().replaceFirst(RegExp(r'^/'), '').toLowerCase();
    for (final pack in _skillPacks) {
      if (pack.shortcut == normalized) return pack;
    }
    return null;
  }

  Future<SkillPack> saveSkillPack({
    String? id,
    required String name,
    required String shortcut,
    required List<String> skillIds,
    String description = '',
  }) async {
    await loaded;
    return _serializeMutation(() async {
      final normalizedShortcut = shortcut
          .trim()
          .replaceFirst(RegExp(r'^/'), '')
          .toLowerCase();
      final currentIndex = id == null
          ? -1
          : _skillPacks.indexWhere((pack) => pack.id == id);
      final current = currentIndex < 0 ? null : _skillPacks[currentIndex];
      if (id != null && current == null) {
        throw StateError('skill_pack_not_found');
      }
      if (_skillPacks.any((pack) =>
          pack.id != id && pack.shortcut == normalizedShortcut)) {
        throw const FormatException('skill_pack_shortcut_already_exists');
      }
      final validIds = <String>[];
      for (final skillId in skillIds) {
        if (_skills.any((skill) => skill.record.id == skillId) &&
            !validIds.contains(skillId)) {
          validIds.add(skillId);
        }
      }
      final now = DateTime.now().toUtc();
      final pack = SkillPack(
        id: id ?? 'pack-${slugify(name)}-${now.microsecondsSinceEpoch.toRadixString(36)}',
        name: name.trim(),
        shortcut: normalizedShortcut,
        skillIds: List.unmodifiable(validIds),
        enabled: current?.enabled ?? false,
        createdAt: current?.createdAt ?? now,
        updatedAt: now,
        description: description.trim(),
        autoDetected: false,
      );
      pack.validate();

      // Packs are non-destructive references to installed Skills. Never move
      // a member out of another pack, rewrite its SkillRecord, or delete a
      // previous pack as a side effect of composing a new one. Overlapping
      // packs are valid and every original Skill remains a first-class item.
      final nextPacks = List<SkillPack>.of(_skillPacks);
      if (current == null) {
        nextPacks.add(pack);
      } else {
        nextPacks[currentIndex] = pack;
      }
      for (var index = 0; index < nextPacks.length; index++) {
        final item = nextPacks[index];
        await store.upsert(
          ExtensionEntityStore.kindSkillPack,
          item.id,
          item.toJson(),
          sortOrder: index,
        );
      }
      _skillPacks
        ..clear()
        ..addAll(nextPacks);
      notifyListeners();
      return pack;
    });
  }

  Future<void> setSkillPackEnabled(String id, bool enabled) async {
    await loaded;
    await _serializeMutation(() async {
      final index = _skillPacks.indexWhere((pack) => pack.id == id);
      if (index < 0) throw StateError('skill_pack_not_found');
      final next = _skillPacks[index].copyWith(
        enabled: enabled,
        updatedAt: DateTime.now().toUtc(),
      );
      await store.upsert(
        ExtensionEntityStore.kindSkillPack,
        id,
        next.toJson(),
        sortOrder: index,
      );
      _skillPacks[index] = next;
      notifyListeners();
    });
  }

  Future<void> deleteSkillPack(String id) async {
    await loaded;
    await _serializeMutation(() async {
      final pack = _skillPacks.where((item) => item.id == id).firstOrNull;
      if (pack == null) return;
      await store.delete(ExtensionEntityStore.kindSkillPack, id);
      _skillPacks.removeWhere((item) => item.id == id);
      notifyListeners();
    });
  }

  Future<void> reorderSkillPacks(int oldIndex, int newIndex) async {
    await loaded;
    await _serializeMutation(() async {
      if (oldIndex < 0 || oldIndex >= _skillPacks.length) return;
      if (newIndex > oldIndex) newIndex--;
      newIndex = newIndex.clamp(0, _skillPacks.length - 1).toInt();
      final pack = _skillPacks.removeAt(oldIndex);
      _skillPacks.insert(newIndex, pack);
      for (var index = 0; index < _skillPacks.length; index++) {
        final item = _skillPacks[index];
        await store.upsert(
          ExtensionEntityStore.kindSkillPack,
          item.id,
          item.toJson(),
          sortOrder: index,
        );
      }
      notifyListeners();
    });
  }

  Future<Skill> updateFromRegisteredGitHub(
    String id, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    final registered = await _extensionRegistry.get('skill', id);
    final rawSource = registered?.source.uri;
    final parsed = rawSource == null ? null : GitHubSkillRef.tryParse(rawSource);
    if (parsed == null) {
      throw StateError('skill_source_not_updatable');
    }
    final ref = GitHubSkillRef(
      owner: parsed.owner,
      repo: parsed.repo,
      ref: parsed.ref ?? registered?.source.ref ?? registered?.source.revision,
      subdir: parsed.subdir ?? registered?.source.subpath,
    );
    final source = _canonicalGitHubSkillSource(
      ref,
      ref.ref ?? 'main',
    );
    return updateFromGitHub(
      id,
      source,
      onProgress: onProgress,
      cancelSignal: cancelSignal,
    );
  }

  /// Updates an installed Skill using the source recorded at installation.
  /// GitHub and skills.sh sources are supported; local/pasted Skills remain
  /// editable and exportable but cannot be refreshed from a remote origin.
  Future<Skill> updateFromRegistered(
    String id, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    final registered = await _extensionRegistry.get('skill', id);
    if (registered == null) throw StateError('skill_not_registered');
    if (registered.source.type == 'skills_sh') {
      return updateFromSkillsCatalog(
        id,
        catalogId: _catalogSkillId(registered),
        onProgress: onProgress,
        cancelSignal: cancelSignal,
      );
    }
    if (registered.source.type == SkillSource.github.name ||
        registered.source.uri?.contains('github.com') == true) {
      return updateFromRegisteredGitHub(
        id,
        onProgress: onProgress,
        cancelSignal: cancelSignal,
      );
    }
    throw StateError('skill_source_not_updatable');
  }

  /// Refreshes a skills.sh-backed Skill while preserving its local Kelivo ID,
  /// all supporting files, and a rollback snapshot of the previous version.
  Future<Skill> updateFromSkillsCatalog(
    String skillId, {
    String? catalogId,
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    final registered = await _extensionRegistry.get('skill', skillId);
    if (registered == null ||
        registered.source.type != 'skills_sh') {
      throw StateError('skill_not_skills_catalog_source');
    }
    final resolvedId = catalogId ?? _catalogSkillId(registered);
    if (resolvedId == null || !_isValidCatalogSkillId(resolvedId)) {
      throw const FormatException('invalid_skills_catalog_source_reference');
    }
    final prepared = await _prepareSkillsShUpdate(
      skillId,
      resolvedId,
      onProgress: onProgress,
      cancelSignal: cancelSignal,
    );
    final updated = await _commitSkillsShUpdates(
      [prepared],
      onProgress: onProgress,
      cancelSignal: cancelSignal,
    );
    return updated.single;
  }

  /// Refreshes all members of one skills.sh repository pack. All remote
  /// bundles are resolved and validated before any installed files are
  /// replaced, preventing a half-updated toolkit when one member is missing.
  Future<List<Skill>> updateSkillPackFromSkillsCatalog(
    String packId, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    final pack = _skillPacks.where((item) => item.id == packId).firstOrNull;
    if (pack == null) throw StateError('skill_pack_not_found');
    if (!pack.autoDetected) throw StateError('skill_pack_not_repository_group');
    final prepared = <_PreparedSkillsShUpdate>[];
    for (final id in pack.skillIds) {
      final registered = await _extensionRegistry.get('skill', id);
      final catalogId = registered == null ? null : _catalogSkillId(registered);
      if (registered == null ||
          registered.source.type != 'skills_sh' ||
          catalogId == null) {
        throw FormatException('skill_pack_member_has_no_skills_catalog_source:$id');
      }
      prepared.add(
        await _prepareSkillsShUpdate(
          id,
          catalogId,
          onProgress: onProgress,
          cancelSignal: cancelSignal,
        ),
      );
    }
    return _commitSkillsShUpdates(
      prepared,
      onProgress: onProgress,
      cancelSignal: cancelSignal,
    );
  }

  /// Updates a repository-backed pack using its recorded source family.
  /// Mixed-source manual packs are intentionally rejected rather than partly
  /// refreshing only some members.
  Future<List<Skill>> updateSkillPack(
    String packId, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    final pack = _skillPacks.where((item) => item.id == packId).firstOrNull;
    if (pack == null) throw StateError('skill_pack_not_found');
    if (!pack.autoDetected) throw StateError('skill_pack_not_repository_group');
    final families = pack.skillIds.map(_updateFamilyForSkill).toSet();
    if (families.length != 1 || families.contains(null)) {
      throw StateError('skill_pack_mixed_or_unsupported_sources');
    }
    return switch (families.single) {
      'github' => updateSkillPackFromGitHub(
        packId,
        onProgress: onProgress,
        cancelSignal: cancelSignal,
      ),
      'skills-sh' => updateSkillPackFromSkillsCatalog(
        packId,
        onProgress: onProgress,
        cancelSignal: cancelSignal,
      ),
      _ => throw StateError('skill_pack_mixed_or_unsupported_sources'),
    };
  }

  /// Updates all installed Skills that still have a supported remote source.
  /// Repository packs are updated as a unit; standalone Skills are refreshed
  /// individually. One failed source does not prevent other packs from being
  /// updated, and failures are returned by the installed Skill ID.
  Future<({List<Skill> updated, Map<String, String> failed})>
  updateAllFromRegisteredSources({
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    var cancelled = false;
    unawaited(
      cancelSignal?.then<void>((_) {
        cancelled = true;
      }),
    );
    void checkCancelled() {
      if (cancelled) throw http.RequestAbortedException();
    }
    final updated = <Skill>[];
    final failed = <String, String>{};
    final processed = <String>{};

    Future<void> updateOne(String id) async {
      checkCancelled();
      processed.add(id);
      if (!canUpdateSkill(id)) return;
      try {
        updated.add(
          await updateFromRegistered(
            id,
            onProgress: onProgress,
            cancelSignal: cancelSignal,
          ),
        );
      } catch (error) {
        failed[id] = error.toString();
      }
    }

    for (final pack in List<SkillPack>.from(
      _skillPacks.where((item) => item.autoDetected),
    )) {
      checkCancelled();
      final members = List<String>.from(pack.skillIds);
      if (canUpdateSkillPack(pack.id)) {
        processed.addAll(members);
        try {
          updated.addAll(
            await updateSkillPack(
              pack.id,
              onProgress: onProgress,
              cancelSignal: cancelSignal,
            ),
          );
        } catch (error) {
          for (final id in members) {
            failed[id] = error.toString();
          }
        }
      } else {
        for (final id in members) {
          await updateOne(id);
        }
      }
    }

    for (final skill in List<Skill>.from(_skills)) {
      checkCancelled();
      if (!processed.contains(skill.record.id)) {
        await updateOne(skill.record.id);
      }
    }
    return (
      updated: List<Skill>.unmodifiable(updated),
      failed: Map<String, String>.unmodifiable(failed),
    );
  }

  Future<_PreparedSkillsShUpdate> _prepareSkillsShUpdate(
    String skillId,
    String catalogId, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    var cancelled = false;
    unawaited(
      cancelSignal?.then<void>((_) {
        cancelled = true;
      }),
    );
    void checkCancelled() {
      if (cancelled) throw http.RequestAbortedException();
    }
    onProgress?.call(const SkillImportProgress(SkillImportPhase.resolving));
    checkCancelled();
    final bundle = await _skillsCatalogAdapter.resolve(catalogId);
    checkCancelled();
    if (bundle.id != catalogId) {
      throw const FormatException('skills_catalog_id_mismatch');
    }
    if (bundle.unsupportedPaths.isNotEmpty || bundle.notes.isNotEmpty) {
      throw FormatException(
        'skills_catalog_update_incomplete:${bundle.unsupportedPaths.join(',')}',
      );
    }
    final existingReport = await getImportReport(skillId);
    final existingFiles = existingReport?['files'];
    if (existingFiles is List) {
      final incomingPaths = bundle.files.keys.toSet();
      final missingAssets = existingFiles.whereType<Map>()
          .where((entry) => entry['scope'] != 'shared')
          .map((entry) => entry['path'])
          .whereType<String>()
          .where((path) => !incomingPaths.contains(path))
          .toList(growable: false);
      if (missingAssets.isNotEmpty) {
        throw FormatException(
          'skills_catalog_update_would_drop_existing_assets:${missingAssets.join(',')}',
        );
      }
    }
    final markdownBytes = bundle.files['SKILL.md'];
    if (markdownBytes == null) {
      throw const FormatException('skills_catalog_skill_md_missing');
    }
    final markdown = utf8.decode(markdownBytes, allowMalformed: false);
    final frontmatter = SkillFrontmatter.parse(markdown);
    final errors = frontmatter.validate(directoryName: catalogId.split('/').last);
    if (errors.isNotEmpty) {
      throw FormatException('Invalid Agent Skill: ${errors.join(', ')}');
    }
    final files = <String, List<int>>{};
    for (final entry in bundle.files.entries) {
      final safePath = safeZipEntryName(entry.key);
      if (safePath == null || safePath != entry.key) {
        throw const FormatException('unsafe_skills_catalog_file_path');
      }
      files[safePath] = List<int>.unmodifiable(entry.value);
    }
    if (!files.containsKey('SKILL.md')) {
      throw const FormatException('skills_catalog_skill_md_missing');
    }
    return _PreparedSkillsShUpdate(
      skillId: skillId,
      catalogId: catalogId,
      bundle: bundle,
      files: Map.unmodifiable(files),
    );
  }

  Future<List<Skill>> _commitSkillsShUpdates(
    List<_PreparedSkillsShUpdate> prepared, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    if (prepared.isEmpty) return const <Skill>[];
    final root = await _ensureRoot();
    final staging = await root.createTemp('.skills-sh-update-');
    var cancelled = false;
    unawaited(
      cancelSignal?.then<void>((_) {
        cancelled = true;
      }),
    );
    void checkCancelled() {
      if (cancelled) throw http.RequestAbortedException();
    }
    try {
      // Build every replacement off to the side before touching an installed
      // Skill. The catalog adapter already enforces safe relative paths.
      onProgress?.call(const SkillImportProgress(SkillImportPhase.downloading));
      for (final item in prepared) {
        await _writeSkillFiles(staging, item.skillId, item.files);
      }
      onProgress?.call(const SkillImportProgress(SkillImportPhase.installing));
      return await _serializeMutation(() async {
        final oldSkills = <String, Skill>{};
        final oldExtensions = <String, ExtensionRecord?>{};
        final movedIds = <String>[];
        final updated = <Skill>[];
        try {
          for (final item in prepared) {
            checkCancelled();
            final current = _require(item.skillId);
            oldSkills[item.skillId] = current;
            oldExtensions[item.skillId] = await _extensionRegistry.get(
              'skill',
              item.skillId,
            );
            await _snapshotSkillVersion(current);

            final destination = Directory(p.join(root.path, item.skillId));
            final backup = Directory(
              p.join(staging.path, '.backups', item.skillId),
            );
            await backup.parent.create(recursive: true);
            await destination.rename(backup.path);
            movedIds.add(item.skillId);
            final replacement = Directory(p.join(staging.path, item.skillId));
            await replacement.rename(destination.path);

            final now = DateTime.now().toUtc();
            final nextRecord = current.record.copyWith(
              source: SkillSource.skillsSh,
              updatedAt: now,
            );
            await store.upsert(
              ExtensionEntityStore.kindSkill,
              item.skillId,
              nextRecord.toJson(),
            );
            final nextSkill = await _skillFromDisk(root, nextRecord);
            await _syncSkillExtension(
              nextSkill,
              sourceUri: item.bundle.sourceUrl ??
                  'https://skills.sh/${item.catalogId}',
              sourceRef: item.catalogId,
              sourceRevision: item.bundle.hash,
            );
            await _refreshSkillImportManifestAfterUpdate(
              skillId: item.skillId,
              sourceType: 'skills_sh',
              sourceUrl: item.bundle.sourceUrl ?? 'https://skills.sh/${item.catalogId}',
              repository: item.bundle.repository,
              ref: item.catalogId,
              completenessNote: 'Updated from the skills.sh text snapshot; previously imported repository-shared resources remain pinned to their original snapshot.',
            );
            final index = _skills.indexWhere(
              (skill) => skill.record.id == item.skillId,
            );
            if (index >= 0) {
              _skills[index] = nextSkill;
            } else {
              _skills.add(nextSkill);
            }
            updated.add(nextSkill);
          }
          await _loadSkillPacksAndDetectRepositories(_skills);
          if (!_disposed) notifyListeners();
          return List<Skill>.unmodifiable(updated);
        } catch (_) {
          for (final id in movedIds.reversed) {
            final destination = Directory(p.join(root.path, id));
            if (await destination.exists()) {
              await destination.delete(recursive: true);
            }
            final backup = Directory(p.join(staging.path, '.backups', id));
            if (await backup.exists()) await backup.rename(destination.path);
            final previous = oldSkills[id];
            if (previous != null) {
              await store.upsert(
                ExtensionEntityStore.kindSkill,
                id,
                previous.record.toJson(),
              );
              final index = _skills.indexWhere((skill) => skill.record.id == id);
              if (index >= 0) {
                _skills[index] = previous;
              } else {
                _skills.add(previous);
              }
            }
            final previousExtension = oldExtensions[id];
            if (previousExtension != null) {
              await _extensionRegistry.upsert(previousExtension);
            } else {
              await _extensionRegistry.remove('skill', id);
            }
            await _restoreLatestSkillImportManifest(id);
          }
          rethrow;
        }
      });
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Updates every member of a repository-backed pack from one archive
  /// download per distinct GitHub repository/ref. This avoids downloading the
  /// same 11-skill repository 11 times when a pack represents one toolkit.
  Future<List<Skill>> updateSkillPackFromGitHub(
    String packId, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    await loaded;
    final pack = _skillPacks.where((item) => item.id == packId).firstOrNull;
    if (pack == null) throw StateError('skill_pack_not_found');
    if (!pack.autoDetected) throw StateError('skill_pack_not_repository_group');

    final groups = <String, List<({String id, ExtensionRecord record, GitHubSkillRef ref})>>{};
    for (final id in pack.skillIds) {
      final registered = await _extensionRegistry.get('skill', id);
      final source = registered?.source.uri;
      final parsed = source == null ? null : GitHubSkillRef.tryParse(source);
      if (registered == null || parsed == null) {
        throw FormatException('skill_pack_member_has_no_github_source:$id');
      }
      final ref = GitHubSkillRef(
        owner: parsed.owner,
        repo: parsed.repo,
        ref: parsed.ref ?? registered.source.ref ?? registered.source.revision ?? 'main',
        subdir: parsed.subdir ?? registered.source.subpath,
      );
      final refName = ref.ref ?? 'main';
      final key = '${ref.owner.toLowerCase()}/${ref.repo.toLowerCase()}@$refName';
      groups.putIfAbsent(key, () => <({String id, ExtensionRecord record, GitHubSkillRef ref})>[])
        .add((id: id, record: registered, ref: ref));
    }

    final updated = <Skill>[];
    for (final members in groups.values) {
      if (members.length == 1) {
        updated.add(await updateFromRegisteredGitHub(
          members.single.id,
          onProgress: onProgress,
          cancelSignal: cancelSignal,
        ));
      } else {
        updated.addAll(await _updateGitHubRepositoryMembers(
          members,
          onProgress: onProgress,
          cancelSignal: cancelSignal,
        ));
      }
    }
    return List.unmodifiable(updated);
  }

  Future<List<Skill>> _updateGitHubRepositoryMembers(
    List<({String id, ExtensionRecord record, GitHubSkillRef ref})> members, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    var cancelled = false;
    unawaited(cancelSignal?.then<void>((_) {
      cancelled = true;
    }));
    void checkCancelled() {
      if (cancelled) throw http.RequestAbortedException();
    }

    final first = members.first;
    final refName = first.ref.ref ?? first.record.source.ref ?? first.record.source.revision ?? 'main';
    final commonSegments = first.ref.subdir?.split('/') ?? <String>[];
    for (final member in members.skip(1)) {
      final segments = member.ref.subdir?.split('/') ?? <String>[];
      var shared = 0;
      while (shared < commonSegments.length &&
          shared < segments.length &&
          commonSegments[shared] == segments[shared]) {
        shared++;
      }
      commonSegments.removeRange(shared, commonSegments.length);
    }
    final commonPath = commonSegments.join('/');
    final repositoryRef = GitHubSkillRef(
      owner: first.ref.owner,
      repo: first.ref.repo,
      ref: refName,
      subdir: commonPath.isEmpty ? null : commonPath,
    );

    onProgress?.call(const SkillImportProgress(SkillImportPhase.resolving));
    final revision = await _resolveGitHubRef(repositoryRef, cancelSignal: cancelSignal);
    final commit = await _resolveGitHubCommitSha(repositoryRef, revision);
    checkCancelled();
    final root = await _ensureRoot();
    final staging = await root.createTemp('.pack-update-');
    try {
      final zip = File(p.join(staging.path, 'download.zip'));
      await _downloadGitHubZip(
        repositoryRef,
        revision,
        zip,
        onProgress: onProgress,
        cancelSignal: cancelSignal,
      );
      checkCancelled();
      onProgress?.call(const SkillImportProgress(SkillImportPhase.extracting));
      final extracted = Directory(p.join(staging.path, 'extracted'));
      final folders = await compute(_extractMultipleArchive, (
        zip.path,
        extracted.path,
        repositoryRef.subdir,
        true,
      ));
      checkCancelled();

      final candidates = <({String id, ExtensionRecord record, GitHubSkillRef ref, Directory folder})>[];
      for (final member in members) {
        checkCancelled();
        final fullPath = member.ref.subdir;
        // extractSkillArchiveMultiple returns repository-relative path keys,
        // even when extraction is constrained to a common subdirectory.
        final archiveSkillPath = fullPath == null || fullPath.isEmpty
            ? '.'
            : fullPath;
        final extractedPath = folders[archiveSkillPath];
        if (extractedPath == null) {
          throw FormatException('skill_directory_missing:${member.id}:$archiveSkillPath');
        }
        final folder = Directory(p.join(extracted.path, extractedPath));
        final markdownFile = File(p.join(folder.path, 'SKILL.md'));
        if (!await markdownFile.exists()) {
          throw FormatException('skill_markdown_missing:${member.id}');
        }
        final parsed = SkillFrontmatter.parse(await markdownFile.readAsString());
        final directoryName = archiveSkillPath == '.'
            ? ''
            : p.posix.basename(archiveSkillPath);
        final errors = parsed.validate(
          directoryName: directoryName.isEmpty ? null : directoryName,
        );
        if (errors.isNotEmpty) {
          throw FormatException('invalid_skill_markdown:${member.id}:${errors.join(',')}');
        }
        candidates.add((
          id: member.id,
          record: member.record,
          ref: member.ref,
          folder: folder,
        ));
      }

      onProgress?.call(const SkillImportProgress(SkillImportPhase.installing));
      return await _serializeMutation(() async {
        final holds = <String, Directory>{};
        final originals = <String, Skill>{};
        final results = <Skill>[];
        try {
          for (final candidate in candidates) {
            checkCancelled();
            final current = _require(candidate.id);
            originals[candidate.id] = current;
            await _snapshotSkillVersion(current);
            final destination = Directory(p.join(root.path, candidate.id));
            final hold = Directory(p.join(staging.path, 'previous-${candidate.id}'));
            await destination.rename(hold.path);
            holds[candidate.id] = hold;
            await candidate.folder.rename(destination.path);

            final now = DateTime.now().toUtc();
            final nextRecord = current.record.copyWith(
              source: SkillSource.github,
              updatedAt: now,
            );
            await store.upsert(
              ExtensionEntityStore.kindSkill,
              candidate.id,
              nextRecord.toJson(),
            );
            final fresh = await _skillFromDisk(root, nextRecord);
            final index = _skills.indexWhere((skill) => skill.record.id == candidate.id);
            if (index < 0) throw StateError('skill_pack_member_disappeared:${candidate.id}');
            _skills[index] = fresh;
            await _syncSkillExtension(
              fresh,
              sourceUri: _canonicalGitHubSkillSource(candidate.ref, revision),
              sourceRef: candidate.ref.ref ?? revision,
              sourceSubpath: candidate.ref.subdir,
              sourceRevision: revision,
            );
            await _refreshSkillImportManifestAfterUpdate(
              skillId: candidate.id,
              sourceType: SkillSource.github.name,
              sourceUrl: _canonicalGitHubSkillSource(candidate.ref, revision),
              repository: '${candidate.ref.owner}/${candidate.ref.repo}',
              ref: candidate.ref.ref ?? revision,
              commit: commit,
              completenessNote: 'Repository Skill folders were refreshed; repository-level shared resources remain pinned to the previously imported snapshot and were not refreshed by this updater.',
            );
            results.add(fresh);
          }
          _skills.sort((a, b) => a.record.id.compareTo(b.record.id));
          notifyListeners();
          return List<Skill>.unmodifiable(results);
        } catch (_) {
          for (final id in holds.keys.toList().reversed) {
            final destination = Directory(p.join(root.path, id));
            if (await destination.exists()) await destination.delete(recursive: true);
            final hold = holds[id];
            if (hold != null && await hold.exists()) await hold.rename(destination.path);
          }
          for (final entry in originals.entries) {
            final original = entry.value;
            await store.upsert(
              ExtensionEntityStore.kindSkill,
              entry.key,
              original.record.toJson(),
            );
            final restored = await _skillFromDisk(root, original.record);
            final index = _skills.indexWhere((skill) => skill.record.id == entry.key);
            if (index >= 0) _skills[index] = restored;
            final oldSource = candidates.firstWhere((candidate) => candidate.id == entry.key).record.source;
            await _syncSkillExtension(
              restored,
              sourceUri: oldSource.uri,
              sourceRef: oldSource.ref,
              sourceSubpath: oldSource.subpath,
              sourceRevision: oldSource.revision,
            );
            await _restoreLatestSkillImportManifest(entry.key);
          }
          notifyListeners();
          rethrow;
        }
      });
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  List<Skill> resolveForAssistant(
    Assistant? assistant, {
    List<String>? conversationOverride,
  }) {
    final filter = conversationOverride ?? assistant?.skillIds;
    final explicitlyAllowed = filter?.toSet();
    if (explicitlyAllowed != null) {
      // Assistant/workspace/conversation selections are exact Skill IDs.
      // Selecting one member must never silently expand to its entire pack.
      return [
        for (final skill in _skills)
          if (explicitlyAllowed.contains(skill.record.id)) skill,
      ];
    }

    final activatedPackMemberIds = <String>{
      for (final pack in _skillPacks)
        if (pack.enabled) ...pack.skillIds,
    };
    return [
      for (final skill in _skills)
        if (skill.record.enabled ||
            activatedPackMemberIds.contains(skill.record.id))
          skill,
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsHttpClient) _httpClient.close();
    super.dispose();
  }

  Future<Skill> _importMarkdown(String markdown, SkillSource source) async {
    await loaded;
    final parsed = SkillFrontmatter.parse(markdown);
    final errors = parsed.validate();
    if (errors.isNotEmpty) {
      throw FormatException('Invalid SKILL.md: ${errors.join(', ')}');
    }
    final files = <String, List<int>>{'SKILL.md': utf8.encode(markdown)};
    return _commitImport(name: parsed.name, files: files, source: source);
  }

  Future<Skill> _commitImport({
    required String name,
    required Map<String, List<int>> files,
    required SkillSource source,
  }) => _serializeMutation(() async {
    final root = await _ensureRoot();
    final id = await _allocateId(slugify(name));
    await _writeSkillFiles(root, id, files);
    final skill = await _registerImport(root, id, source);
    if (source == SkillSource.github || source == SkillSource.skillsSh) {
      await _loadSkillPacksAndDetectRepositories(_skills);
      if (!_disposed) notifyListeners();
    }
    return skill;
  });

  Future<Skill> _registerImport(
    Directory root,
    String id,
    SkillSource source, {
    bool writeDefaultImportManifest = true,
  }) async {
    final now = DateTime.now().toUtc();
    final record = SkillRecord(
      id: id,
      source: source,
      installedAt: now,
      updatedAt: now,
    );
    await _upsertRecord(record);
    late final Skill skill;
    try {
      skill = await _skillFromDisk(root, record);
      if (writeDefaultImportManifest) {
        await _writeSkillImportManifest(
          skillId: id,
          skillDirectory: Directory(p.join(root.path, id)),
          sourceType: source.name,
        );
      }
    } catch (_) {
      await store.delete(ExtensionEntityStore.kindSkill, id);
      await _extensionRegistry.remove('skill', id);
      await _deleteSkillImportManifest(id);
      final incompleteDirectory = Directory(p.join(root.path, id));
      if (await incompleteDirectory.exists()) {
        await incompleteDirectory.delete(recursive: true);
      }
      rethrow;
    }
    _skills
      ..removeWhere((item) => item.record.id == id)
      ..add(skill)
      ..sort((a, b) => a.record.id.compareTo(b.record.id));
    notifyListeners();
    return skill;
  }

  Future<void> _writeSkillImportManifest({
    required String skillId,
    required Directory skillDirectory,
    required String sourceType,
    String? sourceUrl,
    String? repository,
    String? ref,
    String? commit,
    Directory? sharedDirectory,
    String? sharedResourceSetId,
    List<String> sharedResourcePaths = const <String>[],
    List<SkillImportSkippedEntry> skipped = const <SkillImportSkippedEntry>[],
    Map<String, bool?> executableOverrides = const <String, bool?>{},
    Map<String, bool?> sharedExecutableOverrides = const <String, bool?>{},
    String completeness = 'complete',
    List<String> completenessNotes = const <String>[],
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}$').hasMatch(skillId)) {
      throw const FormatException('invalid_skill_manifest_id');
    }
    final manifest = await SkillImportAnalyzer.analyzeDirectory(
      skillId: skillId,
      directory: skillDirectory,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
      repository: repository,
      ref: ref,
      commit: commit,
      sharedDirectory: sharedDirectory,
      sharedResourceSetId: sharedResourceSetId,
      sharedResourcePaths: sharedResourcePaths,
      skipped: skipped,
      executableOverrides: executableOverrides,
      sharedExecutableOverrides: sharedExecutableOverrides,
      completeness: completeness,
      completenessNotes: completenessNotes,
    );
    final root = await _ensureSkillImportMetadataRoot();
    final directory = Directory(p.join(root.path, 'skills'));
    await directory.create(recursive: true);
    final destination = File(p.join(directory.path, '$skillId.json'));
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(manifest.toPrettyJson(), flush: true);
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
  }

  Future<void> _restoreLatestSkillImportManifest(String skillId) async {
    final root = await _ensureRoot();
    final versions = Directory(p.join(root.path, '.versions', skillId));
    if (!await versions.exists()) return;
    final snapshots = <Directory>[];
    await for (final entity in versions.list(followLinks: false)) {
      if (entity is Directory &&
          await File(p.join(entity.path, 'manifest.json')).exists()) {
        snapshots.add(entity);
      }
    }
    if (snapshots.isEmpty) return;
    snapshots.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    await _restoreSkillImportManifestSnapshot(skillId, snapshots.first);
  }

  Future<void> _restoreSkillImportManifestSnapshot(
    String skillId,
    Directory snapshot,
  ) async {
    final metadataRoot = await _ensureSkillImportMetadataRoot();
    final reportDirectory = Directory(p.join(metadataRoot.path, 'skills'));
    await reportDirectory.create(recursive: true);
    final saved = File(p.join(snapshot.path, 'import-manifest.json'));
    final destination = File(p.join(reportDirectory.path, '$skillId.json'));
    if (await saved.exists()) {
      final temporary = File('${destination.path}.restore.tmp');
      await saved.copy(temporary.path);
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
    } else if (await destination.exists()) {
      // Old rollback snapshots predate the Phase 13A sidecar manifest.
      await destination.delete();
    }
  }

  Future<void> _refreshSkillImportManifestAfterUpdate({
    required String skillId,
    required String sourceType,
    required String sourceUrl,
    required String? repository,
    required String? ref,
    String? commit,
    required String completenessNote,
  }) async {
    final previous = await getImportReport(skillId);
    final previousShared = previous?['sharedResources'];
    String? setId;
    Directory? sharedDirectory;
    var sharedPaths = <String>[];
    final hadSharedResources = previousShared is Map &&
        previousShared['paths'] is List &&
        (previousShared['paths'] as List).isNotEmpty;
    if (previousShared is Map) {
      final rawId = previousShared['setId'];
      if (rawId is String && RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(rawId)) {
        final metadataRoot = await _ensureSkillImportMetadataRoot();
        final candidate = Directory(p.join(metadataRoot.path, 'repositories', rawId, 'shared'));
        if (await candidate.exists()) {
          setId = rawId;
          sharedDirectory = candidate;
          final rawPaths = previousShared['paths'];
          if (rawPaths is List) sharedPaths = rawPaths.whereType<String>().toList();
        }
      }
    }
    final oldSkipped = <SkillImportSkippedEntry>[];
    final rawSkipped = previous?['skipped'];
    if (rawSkipped is List) {
      for (final item in rawSkipped.whereType<Map>()) {
        final path = item['path'];
        final reason = item['reason'];
        if (path is String && reason is String) {
          oldSkipped.add(SkillImportSkippedEntry(
            path: path,
            reason: reason,
            scope: item['scope']?.toString() ?? 'skill',
          ));
        }
      }
    }
    await _writeSkillImportManifest(
      skillId: skillId,
      skillDirectory: Directory(p.join((await _ensureRoot()).path, skillId)),
      sourceType: sourceType,
      sourceUrl: sourceUrl,
      repository: repository,
      ref: ref,
      commit: commit,
      sharedDirectory: sharedDirectory,
      sharedResourceSetId: setId,
      sharedResourcePaths: sharedPaths,
      skipped: oldSkipped,
      completeness: !hadSharedResources
          ? 'complete'
          : setId == null
              ? 'update_scope_limited'
              : 'updated_skill_shared_snapshot_retained',
      completenessNotes: hadSharedResources ? <String>[completenessNote] : const <String>[],
    );
  }

  Future<void> _deleteSkillImportManifest(String skillId) async {
    final root = await _ensureSkillImportMetadataRoot();
    final file = File(p.join(root.path, 'skills', '$skillId.json'));
    if (await file.exists()) await file.delete();
  }

  Future<({String id, Directory directory})?> _persistRepositorySharedResources({
    required Directory? sourceDirectory,
    required List<String> paths,
    required String repository,
    required String ref,
    required String? commit,
  }) async {
    if (sourceDirectory == null || paths.isEmpty) return null;
    if (!await sourceDirectory.exists() ||
        await FileSystemEntity.type(sourceDirectory.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw const FormatException('shared_resource_source_not_directory');
    }
    if (paths.length > SkillImportAnalyzer.maxFiles) {
      throw const FormatException('shared_resource_file_limit');
    }
    final canonicalSource = await sourceDirectory.resolveSymbolicLinks();
    final metadataRoot = await _ensureSkillImportMetadataRoot();
    final bundleKey = '$repository|$ref|${commit ?? ''}|${DateTime.now().microsecondsSinceEpoch}';
    final bundleId = sha256.convert(utf8.encode(bundleKey)).toString().substring(0, 24);
    final repositories = Directory(p.join(metadataRoot.path, 'repositories'));
    await repositories.create(recursive: true);
    final staging = await repositories.createTemp('.shared-');
    final shared = Directory(p.join(staging.path, 'shared'));
    var totalBytes = 0;
    final seenPaths = <String>{};
    try {
      for (final rawPath in paths) {
        final normalized = safeZipEntryName(rawPath);
        if (normalized == null || normalized != rawPath || !seenPaths.add(normalized)) {
          throw const FormatException('unsafe_shared_resource_path');
        }
        final source = File(p.join(sourceDirectory.path, normalized));
        if (await FileSystemEntity.type(source.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw FormatException('shared_resource_missing_or_not_regular:$normalized');
        }
        final resolved = await source.resolveSymbolicLinks();
        if (!p.isWithin(canonicalSource, resolved)) {
          throw const FormatException('shared_resource_path_escape');
        }
        final length = await source.length();
        if (length > SkillImportAnalyzer.maxFileBytes) {
          throw FormatException('shared_resource_file_too_large:$normalized');
        }
        totalBytes += length;
        if (totalBytes > SkillImportAnalyzer.maxTotalBytes) {
          throw const FormatException('shared_resource_total_size_limit');
        }
        final destination = File(p.join(shared.path, normalized));
        await destination.parent.create(recursive: true);
        await source.copy(destination.path);
      }
      await File(p.join(staging.path, 'bundle.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'schemaVersion': 1,
          'id': bundleId,
          'repository': repository,
          'ref': ref,
          if (commit != null) 'commit': commit,
          'paths': paths,
          'binding': 'explicit_read_only_reference',
          'runtimeAccessEnabled': false,
        }),
        flush: true,
      );
      final destination = Directory(p.join(repositories.path, bundleId));
      if (await destination.exists()) await destination.delete(recursive: true);
      await staging.rename(destination.path);
      return (id: bundleId, directory: Directory(p.join(destination.path, 'shared')));
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<_PreparedSkillsShArchive> _prepareSkillsShArchive(
    SkillCatalogPackage bundle, {
    Future<void>? cancelSignal,
  }) async {
    final repository = bundle.repository;
    final slug = bundle.slug;
    if (repository == null || slug == null) {
      throw const FormatException('skills_catalog_github_source_unavailable');
    }
    final parts = repository.split('/');
    if (parts.length != 2 ||
        parts.any((part) => !RegExp(r'^[A-Za-z0-9_.-]{1,100}$').hasMatch(part))) {
      throw const FormatException('invalid_skills_catalog_repository');
    }
    final ref = GitHubSkillRef(owner: parts[0], repo: parts[1]);
    final revision = await _resolveGitHubRef(ref, cancelSignal: cancelSignal);
    final commit = await _resolveGitHubCommitSha(ref, revision);
    final root = await _ensureRoot();
    final staging = await root.createTemp('.skills-sh-archive-');
    try {
      final zip = File(p.join(staging.path, 'download.zip'));
      await _downloadGitHubZip(ref, revision, zip, cancelSignal: cancelSignal);
      final extracted = Directory(p.join(staging.path, 'extracted'));
      final extraction = await compute(_extractRepositoryArchive, (
        zip.path, extracted.path, null, true,
      ));
      final folders = _stringMap(extraction['skills']);
      final matching = folders.entries.where((entry) =>
          p.posix.basename(entry.key) == slug).toList();
      final selected = matching.length == 1
          ? matching.single
          : (matching.isEmpty && folders.length == 1 ? folders.entries.single : null);
      if (selected == null) {
        throw FormatException('skills_catalog_skill_slug_not_unique:$slug');
      }
      final directory = Directory(p.join(extracted.path, selected.value));
      if (!await File(p.join(directory.path, 'SKILL.md')).exists()) {
        throw const FormatException('skills_catalog_archive_skill_md_missing');
      }
      return _PreparedSkillsShArchive(
        staging: staging,
        skillDirectory: directory,
        skillPath: selected.key,
        extraction: extraction,
        ref: ref,
        revision: revision,
        commit: commit,
      );
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<String?> _resolveGitHubCommitSha(
    GitHubSkillRef ref,
    String revision,
  ) async {
    if (RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(revision)) return revision.toLowerCase();
    final uri = Uri.https(
      'api.github.com',
      '/repos/${ref.owner}/${ref.repo}/commits/${Uri.encodeComponent(revision)}',
    );
    try {
      var response = await _httpClient.get(uri, headers: _githubHeaders);
      if ((response.statusCode == 401 || response.statusCode == 403 ||
          response.statusCode == 404)) {
        final token = await _credentialStore.readToken();
        if (token != null && token.isNotEmpty) {
          response = await _httpClient.get(uri, headers: {
            ..._githubHeaders,
            'Authorization': 'Bearer $token',
            'X-GitHub-Api-Version': '2022-11-28',
          });
        }
      }
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      final sha = decoded is Map ? decoded['sha']?.toString() : null;
      return sha != null && RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(sha)
          ? sha.toLowerCase() : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) return <String, String>{};
    return <String, String>{
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  static Map<String, bool?> _stringBoolMap(Object? raw) {
    if (raw is! Map) return <String, bool?>{};
    return <String, bool?>{
      for (final entry in raw.entries)
        if (entry.key is String && (entry.value is bool || entry.value == null))
          entry.key as String: entry.value as bool?,
    };
  }

  static Map<String, bool?> _skillModeMap(Object? raw, String skillPath) {
    if (raw is! Map) return <String, bool?>{};
    return _stringBoolMap(raw[skillPath]);
  }

  static List<SkillImportSkippedEntry> _skippedEntries(Object? raw) {
    if (raw is! List) return <SkillImportSkippedEntry>[];
    return <SkillImportSkippedEntry>[
      for (final item in raw.whereType<Map>())
        if (item['path'] is String && item['reason'] is String)
          SkillImportSkippedEntry(
            path: item['path'] as String,
            reason: item['reason'] as String,
            scope: item['scope']?.toString() ?? 'repository',
          ),
    ];
  }

  static Future<int> _directoryFileBytes(Directory? directory) async {
    if (directory == null || !await directory.exists()) return 0;
    var bytes = 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) bytes += await entity.length();
    }
    return bytes;
  }

  Future<void> _writeSkillFiles(
    Directory root,
    String id,
    Map<String, List<int>> files,
  ) async {
    final dest = Directory(p.join(root.path, id));
    if (await dest.exists()) {
      await dest.delete(recursive: true);
    }
    await dest.create(recursive: true);
    final canonRoot = p.canonicalize(dest.path);
    for (final entry in files.entries) {
      final destPath = p.join(dest.path, entry.key);
      final canonDest = p.canonicalize(destPath);
      if (!p.equals(canonRoot, canonDest) &&
          !p.isWithin(canonRoot, canonDest)) {
        throw const FormatException('zip-slip');
      }
      await Directory(p.dirname(destPath)).create(recursive: true);
      await File(destPath).writeAsBytes(entry.value, flush: true);
    }
  }

  Future<String> _allocateId(String base) async {
    final root = await _ensureRoot();
    var id = base;
    var n = 2;
    while (await _idTaken(root, id)) {
      id = '$base-$n';
      n++;
    }
    return id;
  }

  Future<bool> _idTaken(Directory root, String id) async {
    if (_skills.any((skill) => skill.record.id == id)) return true;
    if (await store.get(ExtensionEntityStore.kindSkill, id) != null) {
      return true;
    }
    return Directory(p.join(root.path, id)).exists();
  }

  Future<Skill> _skillFromDisk(Directory root, SkillRecord record) async {
    final dir = p.join(root.path, record.id);
    final mdPath = p.join(dir, 'SKILL.md');
    var name = record.id;
    var description = '';
    try {
      final parsed = SkillFrontmatter.parse(await File(mdPath).readAsString());
      if (parsed.name.trim().isNotEmpty) name = parsed.name.trim();
      description = parsed.description;
    } catch (_) {}
    return Skill(
      record: record,
      name: name,
      description: description,
      dir: dir,
      skillMdPath: mdPath,
    );
  }

  Skill _require(String id) {
    for (final skill in _skills) {
      if (skill.record.id == id) return skill;
    }
    throw StateError('Unknown skill: $id');
  }

  void _replace(
    Skill skill, {
    SkillRecord? record,
    String? name,
    String? description,
  }) {
    final next = Skill(
      record: record ?? skill.record,
      name: name ?? skill.name,
      description: description ?? skill.description,
      dir: skill.dir,
      skillMdPath: skill.skillMdPath,
    );
    final index = _skills.indexWhere(
      (item) => item.record.id == skill.record.id,
    );
    if (index >= 0) {
      _skills[index] = next;
    } else {
      _skills.add(next);
    }
  }

  Future<void> _upsertRecord(SkillRecord record) async {
    await store.upsert(
      ExtensionEntityStore.kindSkill,
      record.id,
      record.toJson(),
    );
    final skill = await _skillFromDisk(await _ensureRoot(), record);
    await _syncSkillExtension(skill);
  }

  Future<void> _syncSkillExtension(
    Skill skill, {
    String? sourceUri,
    String? sourceRef,
    String? sourceSubpath,
    String? sourceRevision,
    bool replaceSourceMetadata = false,
    bool rethrowOnFailure = false,
  }) async {
    try {
      await _extensionRegistry.syncSkill(
        id: skill.record.id,
        name: skill.name,
        description: skill.description,
        sourceType: skill.record.source == SkillSource.skillsSh ? 'skills_sh' : skill.record.source.name,
        enabled: skill.record.enabled,
        installedAt: skill.record.installedAt,
        updatedAt: skill.record.updatedAt,
        sourceUri: sourceUri,
        sourceRef: sourceRef,
        sourceSubpath: sourceSubpath,
        sourceRevision: sourceRevision,
        replaceSourceMetadata: replaceSourceMetadata,
      );
      final registered = await _extensionRegistry.get('skill', skill.record.id);
      if (registered != null) {
        _skillExtensionRecords[skill.record.id] = registered;
      }
    } catch (error, stackTrace) {
      // Registry metadata must never prevent the legacy Skill runtime from
      // loading or saving a user Skill. The source of truth remains the
      // existing SkillRecord until the registry migration is fully adopted.
      debugPrint('Extension registry Skill sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (rethrowOnFailure) rethrow;
    }
  }

  Future<void> _snapshotSkillVersion(Skill skill) async {
    final root = await _ensureRoot();
    final versions = Directory(p.join(root.path, '.versions', skill.record.id));
    await versions.create(recursive: true);
    final versionId = DateTime.now()
        .toUtc()
        .microsecondsSinceEpoch
        .toString()
        .padLeft(20, '0');
    final snapshot = Directory(p.join(versions.path, versionId));
    final files = Directory(p.join(snapshot.path, 'files'));
    await _copySkillDirectory(Directory(skill.dir), files);
    final metadataRoot = await _ensureSkillImportMetadataRoot();
    final currentImportReport = File(
      p.join(metadataRoot.path, 'skills', '${skill.record.id}.json'),
    );
    if (await currentImportReport.exists()) {
      await currentImportReport.copy(p.join(snapshot.path, 'import-manifest.json'));
    }
    final extension = await _extensionRegistry.get('skill', skill.record.id);
    await File(p.join(snapshot.path, 'manifest.json')).writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'skillRecord': skill.record.toJson(),
        if (extension != null) 'extensionRecord': extension.toJson(),
      }),
      flush: true,
    );
    final snapshots = <Directory>[];
    await for (final entity in versions.list(followLinks: false)) {
      if (entity is Directory &&
          await File(p.join(entity.path, 'manifest.json')).exists()) {
        snapshots.add(entity);
      }
    }
    snapshots.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (final old in snapshots.skip(8)) {
      await old.delete(recursive: true);
    }
  }

  Future<void> _copySkillDirectory(
    Directory source,
    Directory destination,
  ) async {
    if (!await source.exists()) {
      throw FileSystemException('Skill directory not found', source.path);
    }
    await destination.create(recursive: true);
    var totalBytes = 0;
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = p
          .relative(entity.path, from: source.path)
          .replaceAll('\\', '/');
      final normalized = p.posix.normalize(relative);
      if (normalized.isEmpty ||
          normalized.startsWith('/') ||
          normalized.split('/').contains('..')) {
        throw const FormatException('unsafe_skill_snapshot_path');
      }
      if (entity is Directory) {
        await Directory(
          p.join(destination.path, normalized),
        ).create(recursive: true);
      } else if (entity is File) {
        totalBytes += await entity.length();
        if (totalBytes > kSkillImportMaxExtractedBytes) {
          throw const FormatException('skill_snapshot_exceeds_500_mb');
        }
        final out = File(p.join(destination.path, normalized));
        await Directory(p.dirname(out.path)).create(recursive: true);
        await entity.copy(out.path);
      }
      // Link entities are intentionally ignored; snapshots never follow links.
    }
  }

  String _canonicalGitHubSkillSource(GitHubSkillRef ref, String branch) {
    if (ref.filePath != null) {
      final segments = <String>[
        ref.owner,
        ref.repo,
        'blob',
        branch.contains('/') ? 'main' : branch,
        ...ref.filePath!.split('/'),
      ];
      return Uri.https(
        'github.com',
        '/${segments.join('/')}',
        branch.contains('/') ? <String, String>{'ref': branch} : null,
      ).toString();
    }
    final subpath = ref.subdir;
    if (branch.contains('/')) {
      final path = <String>[
        ref.owner,
        ref.repo,
        if (subpath != null && subpath.isNotEmpty) ...[
          'tree',
          'main',
          ...subpath.split('/'),
        ],
      ];
      return Uri.https(
        'github.com',
        '/${path.join('/')}',
        {'ref': branch},
      ).toString();
    }
    final segments = <String>[
      ref.owner,
      ref.repo,
      'tree',
      branch,
      if (subpath != null && subpath.isNotEmpty) ...subpath.split('/'),
    ];
    return Uri.https('github.com', '/${segments.join('/')}').toString();
  }

  Future<String> _resolveGitHubRef(
    GitHubSkillRef ref, {
    Future<void>? cancelSignal,
  }) async {
    if (ref.ref != null && ref.ref!.isNotEmpty) return ref.ref!;
    final uri = Uri.https(
      'api.github.com',
      '/repos/${ref.owner}/${ref.repo}',
    );
    var response = await _httpClient.get(uri, headers: _githubHeaders);
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 404) {
      final token = await _credentialStore.readToken();
      if (token != null && token.isNotEmpty) {
        response = await _httpClient.get(uri, headers: {
          ..._githubHeaders,
          'Authorization': 'Bearer $token',
          'X-GitHub-Api-Version': '2022-11-28',
        });
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['default_branch'] != null) {
        final branch = decoded['default_branch'].toString().trim();
        if (branch.isNotEmpty) return branch;
      }
    }
    // Public URLs historically support the common main/master fallback. A
    // private repository without a stored read token is reported by the ZIP
    // request with its HTTP status; never guess a ref for a stored token that
    // GitHub rejected.
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw HttpException(
        'GitHub repository access denied (${response.statusCode}).',
        uri: uri,
      );
    }
    return 'main';
  }

  Future<void> _downloadGitHubZip(
    GitHubSkillRef ref,
    String branch,
    File destination, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    Future<http.StreamedResponse> getPublicZip(String resolved) {
      final uri = Uri(
        scheme: 'https',
        host: 'codeload.github.com',
        pathSegments: <String>[ref.owner, ref.repo, 'zip', resolved],
      );
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: cancelSignal,
      )..headers.addAll(_githubHeaders);
      return _httpClient.send(request);
    }

    onProgress?.call(const SkillImportProgress(SkillImportPhase.downloading));
    var response = branch.contains('/')
        ? await _downloadApiGitHubZip(
            ref,
            branch,
            cancelSignal: cancelSignal,
          )
        : await getPublicZip(branch);
    if (response.statusCode == 404 && ref.ref == null && branch == 'main') {
      await response.stream.listen(null).cancel();
      response = await getPublicZip('master');
    }
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 404) {
      final token = await _credentialStore.readToken();
      if (token != null && token.isNotEmpty) {
        await response.stream.listen(null).cancel();
        response = await _downloadApiGitHubZip(
          ref,
          branch,
          token: token,
          cancelSignal: cancelSignal,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.listen(null).cancel();
      throw HttpException(
        'GitHub zip download failed (${response.statusCode}). '
        'For private repositories, configure a token with repository Contents '
        'read permission.',
        uri: response.request?.url,
      );
    }
    final total = response.contentLength;
    if (total != null && total > kSkillImportMaxBytes) {
      await response.stream.listen(null).cancel();
      throw const FormatException('zip exceeds 200 MB');
    }
    var received = 0;
    final clock = Stopwatch()..start();
    void report() {
      onProgress?.call(
        SkillImportProgress(
          SkillImportPhase.downloading,
          receivedBytes: received,
          totalBytes: total,
        ),
      );
      clock.reset();
    }

    report();
    final output = await destination.open(mode: FileMode.write);
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > kSkillImportMaxBytes) {
          throw const FormatException('zip exceeds 200 MB');
        }
        await output.writeFrom(chunk);
        if (clock.elapsedMilliseconds >= 100) report();
      }
      report();
    } finally {
      await output.close();
    }
  }

  Future<http.StreamedResponse> _downloadApiGitHubZip(
    GitHubSkillRef ref,
    String branch, {
    String? token,
    Future<void>? cancelSignal,
  }) async {
    final apiUri = Uri(
      scheme: 'https',
      host: 'api.github.com',
      pathSegments: <String>[
        'repos',
        ref.owner,
        ref.repo,
        'zipball',
        branch,
      ],
    );
    final request = http.AbortableRequest(
      'GET',
      apiUri,
      abortTrigger: cancelSignal,
    )
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers.addAll({
        ..._githubHeaders,
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'X-GitHub-Api-Version': '2022-11-28',
      });
    var response = await _httpClient.send(request);
    if (response.statusCode == 301 ||
        response.statusCode == 302 ||
        response.statusCode == 303 ||
        response.statusCode == 307 ||
        response.statusCode == 308) {
      final location = response.headers['location'];
      await response.stream.listen(null).cancel();
      if (location == null) {
        throw const HttpException('GitHub private archive redirect is missing.');
      }
      final redirectUri = apiUri.resolve(location);
      final hostAllowed = redirectUri.host == 'codeload.github.com' ||
          redirectUri.host == 'github.com' ||
          redirectUri.host == 'githubusercontent.com' ||
          redirectUri.host.endsWith('.githubusercontent.com');
      if (redirectUri.scheme != 'https' ||
          (redirectUri.hasPort && redirectUri.port != 443) ||
          redirectUri.userInfo.isNotEmpty ||
          !hostAllowed) {
        throw const HttpException('Untrusted GitHub archive redirect.');
      }
      // Do not forward the token to codeload or any redirect host. GitHub
      // returns a short-lived signed archive URL for this unauthenticated hop.
      final redirectRequest = http.AbortableRequest(
        'GET',
        redirectUri,
        abortTrigger: cancelSignal,
      )..headers.addAll(_githubHeaders);
      response = await _httpClient.send(redirectRequest);
    }
    return response;
  }

  static Map<String, String> _extractMultipleArchive(
    (String, String, String?, bool) args,
  ) => extractSkillArchiveMultiple(
    args.$1,
    args.$2,
    subdir: args.$3,
    stripSingleRoot: args.$4,
  );

  static Map<String, Object?> _extractRepositoryArchive(
    (String, String, String?, bool) args,
  ) => extractSkillRepositoryArchive(
    args.$1,
    args.$2,
    subdir: args.$3,
    stripSingleRoot: args.$4,
  );

  static Map<String, Object?> _extractNestedSkillBundle(
    (String, String) args,
  ) => extractNestedSkillBundleArchive(args);

  static String _extractGitHubRepositoryFile(
    (String, String, String, bool) args,
  ) => extractGitHubRepositoryFile(args);

  static const Map<String, String> _githubHeaders = {
    'User-Agent': 'Kelivo',
    'Accept': 'application/vnd.github+json',
  };
}

