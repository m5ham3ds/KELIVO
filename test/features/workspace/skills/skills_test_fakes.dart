import 'dart:io';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class FakeSkillsService extends ChangeNotifier implements SkillsService {
  FakeSkillsService({
    List<Skill>? skills,
    List<SkillPack>? skillPacks,
    this._skillsDirectory,
    this.importError,
  }) : _skills = List<Skill>.from(skills ?? const <Skill>[]),
       _skillPacks = List<SkillPack>.from(skillPacks ?? const <SkillPack>[]);

  final List<Skill> _skills;
  final List<SkillPack> _skillPacks;
  final Directory? _skillsDirectory;

  Object? importError;
  final List<String> importedTexts = <String>[];
  final List<(String, bool)> enabledCalls = <(String, bool)>[];
  final List<String> deletedIds = <String>[];
  final List<(String, String)> updatedBodies = <(String, String)>[];
  final List<(String, String)> linkedUpdateSources = <(String, String)>[];

  @override
  Future<void> loaded = Future<void>.value();

  @override
  Future<Map<String, Object?>?> getImportReport(String skillId) async => null;

  @override
  Future<Map<String, Object?>?> getImportReportWithRequirements(
    String skillId,
  ) async => null;

  @override
  ExtensionEntityStore get store => throw UnimplementedError();

  @override
  Directory get skillsDirectory {
    final dir = _skillsDirectory;
    if (dir == null) {
      throw StateError('FakeSkillsService has no skillsDirectory');
    }
    return dir;
  }

  @override
  List<Skill> get skills => List.unmodifiable(_skills);

  @override
  List<SkillPack> get skillPacks => List.unmodifiable(_skillPacks);

  @override
  SkillPack? packByShortcut(String shortcut) {
    final normalized = shortcut.trim().replaceFirst(RegExp(r'^/'), '').toLowerCase();
    return _skillPacks.where((pack) => pack.shortcut == normalized).firstOrNull;
  }

  @override
  bool canUpdateSkill(String id) => false;

  @override
  bool canUpdateSkillPack(String packId) => false;

  @override
  Future<void> rescan() async {
    notifyListeners();
  }

  @override
  Future<Skill> importFromText(String markdown) async {
    importedTexts.add(markdown);
    final error = importError;
    if (error != null) throw error;
    final parsed = SkillFrontmatter.parse(markdown);
    final errors = parsed.validate();
    if (errors.isNotEmpty) {
      throw FormatException('Invalid SKILL.md: ${errors.join(', ')}');
    }
    final root = _skillsDirectory;
    final id = slugify(parsed.name);
    late final String dir;
    late final String mdPath;
    if (root != null) {
      dir = p.join(root.path, id);
      await Directory(dir).create(recursive: true);
      mdPath = p.join(dir, 'SKILL.md');
      await File(mdPath).writeAsString(markdown);
    } else {
      dir = id;
      mdPath = p.join(id, 'SKILL.md');
    }
    final now = DateTime.now().toUtc();
    final skill = Skill(
      record: SkillRecord(
        id: id,
        source: SkillSource.paste,
        installedAt: now,
        updatedAt: now,
      ),
      name: parsed.name.trim(),
      description: parsed.description,
      dir: dir,
      skillMdPath: mdPath,
    );
    _skills
      ..removeWhere((item) => item.record.id == id)
      ..add(skill);
    notifyListeners();
    return skill;
  }

  @override
  Future<Skill> importFromFile(
    String hostPath, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    final file = File(hostPath);
    if (!await file.exists()) {
      throw FileSystemException('Skill file not found', hostPath);
    }
    if (p.extension(hostPath).toLowerCase() != '.md') {
      throw UnsupportedError('FakeSkillsService only imports Markdown files.');
    }
    return importFromText(await file.readAsString());
  }

  @override
  Future<Skill> importFromDirectory(
    String hostPath, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    final markdown = File(p.join(hostPath, 'SKILL.md'));
    if (!await markdown.exists()) {
      throw FileSystemException('SKILL.md not found', markdown.path);
    }
    return importFromText(await markdown.readAsString());
  }

  @override
  Future<List<Map<String, Object?>>> searchGitHubRepositories(
    String query, {
    int limit = 8,
  }) async => <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>> inspectGitHubSkill(
    String url, {
    Future<void>? cancelSignal,
  }) async {
    throw UnsupportedError('GitHub inspection is not used by this fake.');
  }

  @override
  Future<Skill> updateFromGitHub(
    String id,
    String url, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    throw UnsupportedError('GitHub updates are not used by this fake.');
  }

  @override
  Future<Skill> rollback(String id) async {
    throw UnsupportedError('Rollback is not used by this fake.');
  }

  @override
  Future<Map<String, Object?>> inspectLocalSource(String path) async {
    final entityType = await FileSystemEntity.type(path, followLinks: false);
    final markdownFile = entityType == FileSystemEntityType.directory
        ? File(p.join(path, 'SKILL.md'))
        : File(path);
    if (!await markdownFile.exists() ||
        p.extension(markdownFile.path).toLowerCase() != '.md') {
      throw FormatException('Unsupported fake skill source: $path');
    }
    final parsed = SkillFrontmatter.parse(await markdownFile.readAsString());
    final errors = parsed.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join(', '));
    return <String, Object?>{
      'name': parsed.name,
      'description': parsed.description,
      'source': path,
      'fileCount': 1,
    };
  }

  @override
  Future<String> readSkillMarkdown(
    String id, {
    int maxCharacters = 24000,
  }) async {
    final skill = _skills.firstWhere((item) => item.record.id == id);
    final file = File(skill.skillMdPath);
    final markdown = await file.exists()
        ? await file.readAsString()
        : '---\nname: ${skill.name}\ndescription: ${skill.description}\n---\n';
    return markdown.length <= maxCharacters
        ? markdown
        : '${markdown.substring(0, maxCharacters)}\n\n[truncated]';
  }

  @override
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

  @override
  bool hasRollback(String id) => false;

  @override
  Future<Skill> importFromGitHub(
    String url, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<File> exportZip(String id, Directory outDir) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    _skills.removeWhere((skill) => skill.record.id == id);
    notifyListeners();
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    enabledCalls.add((id, enabled));
    final index = _skills.indexWhere((skill) => skill.record.id == id);
    if (index < 0) return;
    final skill = _skills[index];
    _skills[index] = Skill(
      record: skill.record.copyWith(enabled: enabled),
      name: skill.name,
      description: skill.description,
      dir: skill.dir,
      skillMdPath: skill.skillMdPath,
    );
    notifyListeners();
  }

  @override
  Future<void> setUpdateSource(String skillId, String source) async {
    linkedUpdateSources.add((skillId, source));
    notifyListeners();
  }

  @override
  Future<void> incrementUseCount(String id) async {}

  @override
  Future<void> updateBody(String id, String markdown) async {
    updatedBodies.add((id, markdown));
    final parsed = SkillFrontmatter.parse(markdown);
    final index = _skills.indexWhere((skill) => skill.record.id == id);
    if (index < 0) return;
    final skill = _skills[index];
    _skills[index] = Skill(
      record: skill.record.copyWith(updatedAt: DateTime.now().toUtc()),
      name: parsed.name.trim().isEmpty ? skill.name : parsed.name.trim(),
      description: parsed.description,
      dir: skill.dir,
      skillMdPath: skill.skillMdPath,
    );
    notifyListeners();
  }

  @override
  Future<SkillPack> saveSkillPack({
    String? id,
    required String name,
    required String shortcut,
    required List<String> skillIds,
    String description = '',
  }) async {
    final now = DateTime.now().toUtc();
    final existing = id == null
        ? null
        : _skillPacks.where((pack) => pack.id == id).firstOrNull;
    final pack = SkillPack(
      id: id ?? 'fake-pack-${slugify(name)}',
      name: name,
      shortcut: shortcut.replaceFirst(RegExp(r'^/'), '').toLowerCase(),
      skillIds: List.unmodifiable(skillIds.toSet()),
      enabled: existing?.enabled ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      description: description,
    );
    pack.validate();
    _skillPacks.removeWhere((item) => item.id == pack.id ||
        item.skillIds.any(pack.skillIds.contains));
    _skillPacks.add(pack);
    notifyListeners();
    return pack;
  }

  @override
  Future<void> setSkillPackEnabled(String id, bool enabled) async {
    final index = _skillPacks.indexWhere((pack) => pack.id == id);
    if (index < 0) return;
    _skillPacks[index] = _skillPacks[index].copyWith(enabled: enabled);
    notifyListeners();
  }

  @override
  Future<void> deleteSkillPack(String id) async {
    _skillPacks.removeWhere((pack) => pack.id == id);
    notifyListeners();
  }

  @override
  Future<void> reorderSkillPacks(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _skillPacks.length) return;
    if (newIndex > oldIndex) newIndex--;
    newIndex = newIndex.clamp(0, _skillPacks.length - 1).toInt();
    final pack = _skillPacks.removeAt(oldIndex);
    _skillPacks.insert(newIndex, pack);
    notifyListeners();
  }

  @override
  Future<List<Skill>> updateSkillPack(
    String packId, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async => <Skill>[];

  @override
  Future<({List<Skill> updated, Map<String, String> failed})>
  updateAllFromRegisteredSources({
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async => (updated: <Skill>[], failed: <String, String>{});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  List<Skill> resolveForAssistant(
    Assistant? assistant, {
    List<String>? conversationOverride,
  }) {
    final filter = conversationOverride ?? assistant?.skillIds;
    final enabled = [
      for (final skill in _skills)
        if (skill.record.enabled) skill,
    ];
    if (filter == null) return enabled;
    final allowed = filter.toSet();
    return [
      for (final skill in enabled)
        if (allowed.contains(skill.record.id)) skill,
    ];
  }
}

class FakeChatService extends ChatService {
  FakeChatService({this._conversation});

  Conversation? _conversation;
  Map<String, dynamic>? lastExtras;

  @override
  Conversation? getConversation(String id) {
    final conversation = _conversation;
    if (conversation == null || conversation.id != id) return null;
    return conversation;
  }

  @override
  Future<void> updateConversationExtras(
    String conversationId,
    Map<String, dynamic> Function(Map<String, dynamic> current) update, {
    Conversation? expectedOwner,
  }) async {
    final current = Map<String, dynamic>.from(_conversation?.extras ?? {});
    final next = update(current);
    lastExtras = next;
    final existing = _conversation;
    _conversation = (existing ?? Conversation(id: conversationId, title: 't'))
        .copyWith(extras: next);
    notifyListeners();
  }
}

Skill createTempSkill({
  required String id,
  required String name,
  required String description,
  bool enabled = true,
  int useCount = 0,
  SkillSource source = SkillSource.paste,
  Directory? parent,
}) {
  final dir = parent == null
      ? Directory.systemTemp.createTempSync('kelivo_skill_$id')
      : (Directory(p.join(parent.path, id))..createSync(recursive: true));
  final md = File(p.join(dir.path, 'SKILL.md'));
  md.writeAsStringSync('''
---
name: $name
description: $description
---
# $name
''');
  final now = DateTime.utc(2026, 1, 1);
  return Skill(
    record: SkillRecord(
      id: id,
      enabled: enabled,
      useCount: useCount,
      source: source,
      installedAt: now,
      updatedAt: now,
    ),
    name: name,
    description: description,
    dir: dir.path,
    skillMdPath: md.path,
  );
}
