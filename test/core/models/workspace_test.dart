import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/workspace.dart';

void main() {
  group('Workspace', () {
    final createdAt = DateTime.utc(2026, 9, 2, 12);
    final updatedAt = DateTime.utc(2026, 9, 2, 13);
    final lastUsedAt = DateTime.utc(2026, 9, 2, 14);

    Workspace sample() => Workspace(
      id: 'ws-1',
      name: 'Project',
      kind: WorkspaceKind.linked,
      hostPath: '/tmp/project',
      shellNeedsApproval: true,
      defaultCwd: 'src',
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastUsedAt: lastUsedAt,
    );

    test('defaults shellNeedsApproval and defaultCwd', () {
      final workspace = Workspace(
        id: 'ws-2',
        name: 'Managed',
        kind: WorkspaceKind.managed,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      expect(workspace.shellNeedsApproval, isFalse);
      expect(workspace.defaultCwd, isEmpty);
      expect(workspace.hostPath, isNull);
      expect(workspace.lastUsedAt, isNull);
    });

    test('JSON round trip', () {
      final workspace = sample();
      final decoded = Workspace.fromJson(workspace.toJson());
      expect(decoded, workspace);
    });

    test('tool choices round trip independently and survive other edits', () {
      final original = sample();
      final disabled = original.copyWith(
        disabledTools: {'shell', 'write_file'},
      );
      final reloaded = Workspace.fromJson(disabled.toJson());
      expect(reloaded.isToolEnabled('shell'), isFalse);
      expect(reloaded.isToolEnabled('read_file'), isTrue);
      expect(original.isToolEnabled('shell'), isTrue);
      expect(reloaded.copyWith(name: 'Renamed').disabledTools, {
        'shell',
        'write_file',
      });
      final reordered = original.copyWith(
        disabledTools: {'write_file', 'shell'},
      );
      expect(reordered, reloaded);
      expect(reordered.hashCode, reloaded.hashCode);
      expect(
        reloaded.copyWith(disabledTools: {}).isToolEnabled('shell'),
        isTrue,
      );
    });


    test('Project Default Skills survive JSON and can inherit assistant defaults', () {
      final configured = sample().copyWith(skillIds: ['story-plan', 'renderer']);
      final reloaded = Workspace.fromJson(configured.toJson());
      expect(reloaded.skillIds, ['story-plan', 'renderer']);
      expect(reloaded, configured);
      expect(reloaded.copyWith(name: 'Renamed').skillIds, ['story-plan', 'renderer']);
      expect(reloaded.copyWith(clearSkillIds: true).skillIds, isNull);
    });

    test('Runtime Profile Project Default survives JSON and clear operations', () {
      final configured = sample().copyWith(
        defaultRuntimeProfileId: 'runtime-profile-1',
      );
      final restored = Workspace.fromJson(configured.toJson());
      expect(restored.defaultRuntimeProfileId, 'runtime-profile-1');
      expect(restored, configured);
      expect(restored.copyWith(name: 'Renamed').defaultRuntimeProfileId,
          'runtime-profile-1');
      expect(restored.copyWith(clearDefaultRuntimeProfileId: true)
          .defaultRuntimeProfileId, isNull);
    });

    test('Video Engine default and project settings survive JSON and copyWith', () {
      final configured = sample().copyWith(
        defaultVideoEngineId: 'motion-kit',
        videoEngineSettings: const {
          'motion-kit': {'quality': 'high', 'format': 'mp4'},
        },
      );
      final restored = Workspace.fromJson(configured.toJson());
      expect(restored.defaultVideoEngineId, 'motion-kit');
      expect(restored.videoEngineSettings['motion-kit'], {
        'quality': 'high',
        'format': 'mp4',
      });
      expect(restored, configured);
      final reorderedSettings = sample().copyWith(
        defaultVideoEngineId: 'motion-kit',
        videoEngineSettings: const {
          'motion-kit': {'format': 'mp4', 'quality': 'high'},
        },
      );
      expect(reorderedSettings, configured);
      expect(reorderedSettings.hashCode, configured.hashCode);
      expect(restored.copyWith(name: 'Renamed').videoEngineSettings,
          configured.videoEngineSettings);
      expect(restored.copyWith(clearDefaultVideoEngineId: true)
          .defaultVideoEngineId, isNull);
      expect(restored.copyWith(videoEngineSettings: const {})
          .videoEngineSettings, isEmpty);
    });

    test('older workspace JSON without Video Engine fields remains readable', () {
      final legacyJson = sample().toJson()
        ..remove('defaultVideoEngineId')
        ..remove('videoEngineSettings');
      final restored = Workspace.fromJson(legacyJson);
      expect(restored.defaultVideoEngineId, isNull);
      expect(restored.videoEngineSettings, isEmpty);
    });

    test('equality and copyWith', () {
      final workspace = sample();
      expect(workspace, workspace.copyWith());
      expect(
        workspace.copyWith(name: 'Other', clearHostPath: true),
        Workspace(
          id: 'ws-1',
          name: 'Other',
          kind: WorkspaceKind.linked,
          shellNeedsApproval: true,
          defaultCwd: 'src',
          createdAt: createdAt,
          updatedAt: updatedAt,
          lastUsedAt: lastUsedAt,
        ),
      );
    });
  });
}
