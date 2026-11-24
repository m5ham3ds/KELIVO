import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/skills/skill_mcp_config.dart';
import 'package:Kelivo/core/services/skills/skill_mcp_registry.dart';

void main() {
  late Directory directory;
  late String currentDigest;
  late SkillMcpOwnerRegistry registry;

  const initialDigest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  SkillMcpServerDescriptor descriptor({
    String name = 'youtube-tools',
    String configPath = 'mcp.json',
  }) => SkillMcpServerDescriptor(
    name: name,
    transport: SkillMcpTransport.stdio,
    configPath: configPath,
    command: 'node',
    arguments: const <String>['server.js', '--stdio'],
    requiredEnvironmentVariables: const <String>['YOUTUBE_API_KEY'],
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('skill-mcp-owner-');
    currentDigest = initialDigest;
    registry = SkillMcpOwnerRegistry(
      directory: directory,
      currentSourceDigestForSkill: (_) async => currentDigest,
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists exact Skill ownership and keeps declarations disabled', () async {
    final created = await registry.registerMany(
      skillId: 'youtube-skill',
      sourceDigest: initialDigest,
      capabilityId: SkillMcpOwnerRegistration.requiredCapabilityId,
      descriptors: <SkillMcpServerDescriptor>[descriptor()],
    );

    expect(created, hasLength(1));
    final registration = created.single;
    expect(registration.skillId, 'youtube-skill');
    expect(registration.sourceDigest, initialDigest);
    expect(registration.capabilityId, 'agent_skill.mcp_server');
    expect(registration.enabled, isFalse);
    expect(registration.requiresManualApproval, isTrue);

    final file = File(
      directory.path + '/' + SkillMcpOwnerRegistry.registryFileName,
    );
    final saved = await file.readAsString();
    expect(saved, contains('YOUTUBE_API_KEY'));
    expect(saved, contains(registration.serverId));
    expect(saved, isNot(contains('secret-value')));

    final reloaded = SkillMcpOwnerRegistry(
      directory: directory,
      currentSourceDigestForSkill: (_) async => currentDigest,
    );
    final records = await reloaded.registrationsForSkill('youtube-skill');
    expect(records, hasLength(1));
    expect(records.single.serverId, registration.serverId);
    expect(records.single.enabled, isFalse);
  });

  test('rejects a stale source digest before registering any server', () async {
    currentDigest =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    await expectLater(
      registry.registerMany(
        skillId: 'youtube-skill',
        sourceDigest: initialDigest,
        capabilityId: SkillMcpOwnerRegistration.requiredCapabilityId,
        descriptors: <SkillMcpServerDescriptor>[descriptor()],
      ),
      throwsA(isA<StateError>()),
    );

    final file = File(
      directory.path + '/' + SkillMcpOwnerRegistry.registryFileName,
    );
    expect(await file.exists(), isFalse);
  });

  test('rejects duplicate names atomically within a Skill owner', () async {
    await expectLater(
      registry.registerMany(
        skillId: 'youtube-skill',
        sourceDigest: initialDigest,
        capabilityId: SkillMcpOwnerRegistration.requiredCapabilityId,
        descriptors: <SkillMcpServerDescriptor>[
          descriptor(),
          descriptor(configPath: 'nested/mcp.json'),
        ],
      ),
      throwsA(isA<StateError>()),
    );

    final file = File(
      directory.path + '/' + SkillMcpOwnerRegistry.registryFileName,
    );
    expect(await file.exists(), isFalse);
  });

  test('removes old digest registrations before exposing Skill servers', () async {
    await registry.registerMany(
      skillId: 'youtube-skill',
      sourceDigest: initialDigest,
      capabilityId: SkillMcpOwnerRegistration.requiredCapabilityId,
      descriptors: <SkillMcpServerDescriptor>[descriptor()],
    );
    currentDigest =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

    expect(
      await registry.registrationsForSkill('youtube-skill'),
      isEmpty,
    );
    final file = File(
      directory.path + '/' + SkillMcpOwnerRegistry.registryFileName,
    );
    final saved = jsonDecode(await file.readAsString()) as Map;
    expect(saved['registrations'], isEmpty);
  });

  test('removes all owner records when a Skill is removed', () async {
    await registry.registerMany(
      skillId: 'youtube-skill',
      sourceDigest: initialDigest,
      capabilityId: SkillMcpOwnerRegistration.requiredCapabilityId,
      descriptors: <SkillMcpServerDescriptor>[descriptor()],
    );
    await registry.removeSkill('youtube-skill');
    expect(
      await registry.registrationsForSkill('youtube-skill'),
      isEmpty,
    );
  });

  test('stores secret values separately and only for declared names', () async {
    final registration = (await registry.registerMany(
      skillId: 'youtube-skill',
      sourceDigest: initialDigest,
      capabilityId: SkillMcpOwnerRegistration.requiredCapabilityId,
      descriptors: <SkillMcpServerDescriptor>[descriptor()],
    )).single;
    final secrets = MemorySkillMcpSecretStore();
    await secrets.writeVariable(
      registration,
      'YOUTUBE_API_KEY',
      'secret-value',
    );
    expect(
      await secrets.readVariable(registration, 'YOUTUBE_API_KEY'),
      'secret-value',
    );
    await expectLater(
      secrets.writeVariable(registration, 'UNDECLARED_KEY', 'secret-value'),
      throwsA(isA<FormatException>()),
    );
    final file = File(
      directory.path + '/' + SkillMcpOwnerRegistry.registryFileName,
    );
    expect(await file.readAsString(), isNot(contains('secret-value')));
    await secrets.clearServer(registration);
    expect(
      await secrets.readVariable(registration, 'YOUTUBE_API_KEY'),
      isNull,
    );
  });

  test('fails closed on malformed registry without overwriting it', () async {
    final file = File(
      directory.path + '/' + SkillMcpOwnerRegistry.registryFileName,
    );
    await directory.create(recursive: true);
    const damaged = '{"schemaVersion":1,"registrations":[{"enabled":true}]}';
    await file.writeAsString(damaged);

    await expectLater(
      registry.registrationsForSkill('youtube-skill'),
      throwsA(isA<FormatException>()),
    );
    expect(await file.readAsString(), damaged);
  });
}
