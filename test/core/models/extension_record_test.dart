import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/extension_record.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7);

  ExtensionRecord sample({
    String id = 'remotion-skill',
    String kind = 'skill',
    Map<String, Object?> metadata = const {'description': 'Video creation'},
  }) => ExtensionRecord(
    id: id,
    kind: kind,
    name: 'Remotion Skill',
    source: const ExtensionSource(
      type: 'github',
      uri: 'https://github.com/remotion-dev/skills',
      ref: 'main',
      subpath: 'packages/skills',
    ),
    status: ExtensionLifecycleStatus.validated,
    updatedAt: now,
    compatibility: const {'host': 'kelivo', 'skillFormat': 'agent-skills'},
    permissions: const ['filesystem.read', 'network.https'],
    entryPoint: 'SKILL.md',
    metadata: metadata,
  );

  test(
    'round trips all extension metadata without losing source provenance',
    () {
      final original = sample();
      final decoded = ExtensionRecord.fromJson(original.toJson());

      expect(decoded.id, original.id);
      expect(decoded.kind, original.kind);
      expect(decoded.status, ExtensionLifecycleStatus.validated);
      expect(decoded.source.uri, 'https://github.com/remotion-dev/skills');
      expect(decoded.source.ref, 'main');
      expect(decoded.source.subpath, 'packages/skills');
      expect(decoded.permissions, ['filesystem.read', 'network.https']);
      expect(decoded.storageId, 'skill::remotion-skill');
    },
  );

  test('allows the same extension id in different extension kinds', () {
    expect(sample(kind: 'skill').storageId, 'skill::remotion-skill');
    expect(sample(kind: 'engine').storageId, 'engine::remotion-skill');
  });

  test('rejects credential-bearing metadata and source URLs', () {
    expect(
      () => sample(metadata: const {'apiKey': 'must-not-be-stored'}).toJson(),
      throwsFormatException,
    );
    expect(
      () => ExtensionSource.fromJson({
        'type': 'github',
        'uri': 'https://github.com/org/repo?access_token=secret',
      }),
      throwsFormatException,
    );
    expect(
      () => ExtensionSource.fromJson({
        'type': 'github',
        'uri': 'https://user:password@github.com/org/repo',
      }),
      throwsFormatException,
    );
    expect(
      () => ExtensionSource.fromJson({
        'type': 'github',
        'uri': 'https://github.com/org/repo#access_token=secret',
      }),
      throwsFormatException,
    );
  });

  test(
    'rejects path traversal in extension entrypoints and source subpaths',
    () {
      expect(
        () => sample().copyWith(entryPoint: '../outside').toJson(),
        throwsFormatException,
      );
      expect(
        () => ExtensionSource.fromJson({
          'type': 'github',
          'uri': 'https://github.com/org/repo',
          'subpath': 'skills/../../secrets',
        }),
        throwsFormatException,
      );
      expect(
        () => ExtensionSource.fromJson({
          'type': 'github',
          'uri': 'https://github.com/org/repo',
          'subpath': '/absolute/path',
        }),
        throwsFormatException,
      );
      expect(
        () => ExtensionSource.fromJson({
          'type': 'github',
          'uri': 'https://github.com/org/repo',
          'subpath': 'skills/%2e%2e/secret',
        }),
        throwsFormatException,
      );
    },
  );

  test('serializes update state using the portable snake-case wire value', () {
    final value = sample().copyWith(
      status: ExtensionLifecycleStatus.updateAvailable,
    );
    expect(value.toJson()['status'], 'update_available');
    expect(
      ExtensionRecord.fromJson(value.toJson()).status,
      ExtensionLifecycleStatus.updateAvailable,
    );
  });
}
