import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/video_hybrid/hybrid_workflow_spec.dart';

const _productionScenes = [
  {'id': 'opening', 'title': 'Opening', 'durationSeconds': 4.0},
  {'id': 'middle', 'title': 'Middle', 'durationSeconds': 6.0},
];
const _productionSpec = {
  'width': 1080,
  'height': 1920,
  'fps': 30,
  'durationSeconds': 10.0,
};

void main() {
  group('HybridDependencyPin', () {
    test('pins renderer and provider manifest versions and digests', () {
      const enginePin = HybridDependencyPin(
        version: '1.2.0',
        digest: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      final saved = enginePin.toJson();
      final parsed = HybridDependencyPin.tryParse(saved);
      expect(parsed, isNotNull);
      expect(parsed!.matches(
        '1.2.0',
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      ), isTrue);
      expect(parsed.matches(
        '1.3.0',
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      ), isFalse);
      expect(parsed.matches(
        '1.2.0',
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      ), isFalse);
    });

    test('accepts provider SHA-256 prefix and rejects malformed pins', () {
      final providerPin = HybridDependencyPin.tryParse({
        'version': 'provider-2026.1',
        'digest': 'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      });
      expect(providerPin, isNotNull);
      expect(providerPin!.matches(
        'provider-2026.1',
        'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      ), isTrue);
      expect(HybridDependencyPin.tryParse({'version': '', 'digest': 'bad'}), isNull);
    });
  });

  group('HybridWorkflowSpec', () {
    test('accepts code and provider routes for every scene', () {
      final spec = HybridWorkflowSpec.parse(
        routes: const [
          {
            'scene_id': 'opening',
            'mode': 'code',
            'engine_id': 'motion-kit',
            'skill_ids': ['title-card'],
          },
          {
            'scene_id': 'middle',
            'mode': 'provider',
            'provider_id': 'cinematic-cloud',
            'model': 'cinematic-v1',
          },
        ],
        productionScenes: _productionScenes,
        productionSpec: _productionSpec,
        assemblyEngineId: 'hybrid-compositor',
        audioPolicy: 'prefer_generated',
      );

      expect(spec.routes, hasLength(2));
      expect(spec.routes.first.mode, HybridSceneMode.code);
      expect(spec.routes.last.mode, HybridSceneMode.provider);
      expect(spec.width, 1080);
      expect(spec.height, 1920);
      expect(spec.audioPolicy, 'prefer_generated');
      final saved = spec.toJson(workflowId: 'workflow-1', now: '2026-11-08T00:00:00Z');
      expect(saved['workflowId'], 'workflow-1');
      expect((saved['targetProfile'] as Map)['audioPolicy'], 'prefer_generated');
      expect((saved['sceneStates'] as Map).keys, containsAll(['opening', 'middle']));
      expect(saved.toString(), isNot(contains('image_url')));
      expect(saved.toString(), isNot(contains('api_key')));
    });

    test('restores saved camelCase route JSON', () {
      const route = HybridSceneRoute(
        sceneId: 'opening',
        mode: HybridSceneMode.provider,
        providerId: 'cinematic-cloud',
        model: 'cinematic-v1',
        skillIds: ['title-card'],
      );
      final restored = HybridSceneRoute.fromSavedJson(route.toJson());
      expect(restored.sceneId, route.sceneId);
      expect(restored.mode, route.mode);
      expect(restored.providerId, route.providerId);
      expect(restored.model, route.model);
      expect(restored.skillIds, route.skillIds);
    });

    test('restores legacy snake_case route JSON', () {
      final restored = HybridSceneRoute.fromSavedJson({
        'scene_id': 'opening',
        'mode': 'code',
        'engine_id': 'motion-kit',
        'skill_ids': ['title-card'],
      });
      expect(restored.sceneId, 'opening');
      expect(restored.mode, HybridSceneMode.code);
      expect(restored.engineId, 'motion-kit');
      expect(restored.skillIds, ['title-card']);
    });

    test('requires exactly one route for every scene', () {
      expect(
        () => HybridWorkflowSpec.parse(
          routes: const [
            {'scene_id': 'opening', 'mode': 'code', 'engine_id': 'motion-kit'},
          ],
          productionScenes: _productionScenes,
          productionSpec: _productionSpec,
          assemblyEngineId: 'compositor',
        ),
        throwsA(isA<HybridWorkflowSpecException>()),
      );
      expect(
        () => HybridWorkflowSpec.parse(
          routes: const [
            {'scene_id': 'opening', 'mode': 'code', 'engine_id': 'motion-kit'},
            {'scene_id': 'opening', 'mode': 'provider', 'provider_id': 'cloud'},
          ],
          productionScenes: _productionScenes,
          productionSpec: _productionSpec,
          assemblyEngineId: 'compositor',
        ),
        throwsA(isA<HybridWorkflowSpecException>()),
      );
    });

    test('rejects route mode mismatch, invalid IDs and duplicate skills', () {
      final invalidRoutes = [
        const [
          {'scene_id': 'opening', 'mode': 'code', 'provider_id': 'cloud'},
          {'scene_id': 'middle', 'mode': 'provider', 'provider_id': 'cloud'},
        ],
        const [
          {'scene_id': '../outside', 'mode': 'code', 'engine_id': 'renderer'},
          {'scene_id': 'middle', 'mode': 'provider', 'provider_id': 'cloud'},
        ],
        const [
          {
            'scene_id': 'opening',
            'mode': 'code',
            'engine_id': 'renderer',
            'skill_ids': ['same', 'same'],
          },
          {'scene_id': 'middle', 'mode': 'provider', 'provider_id': 'cloud'},
        ],
      ];
      for (final routes in invalidRoutes) {
        expect(
          () => HybridWorkflowSpec.parse(
            routes: routes,
            productionScenes: _productionScenes,
            productionSpec: _productionSpec,
            assemblyEngineId: 'compositor',
          ),
          throwsA(isA<HybridWorkflowSpecException>()),
        );
      }
    });

    test('rejects incomplete output profiles, invalid audio policy and routes', () {
      expect(
        () => HybridWorkflowSpec.parse(
          routes: const [
            {'scene_id': 'opening', 'mode': 'code', 'engine_id': 'renderer'},
            {'scene_id': 'middle', 'mode': 'provider', 'provider_id': 'cloud'},
          ],
          productionScenes: _productionScenes,
          productionSpec: {..._productionSpec, 'fps': 240},
          assemblyEngineId: 'compositor',
        ),
        throwsA(isA<HybridWorkflowSpecException>()),
      );
      expect(
        () => HybridWorkflowSpec.parse(
          routes: const [
            {'scene_id': 'opening', 'mode': 'code', 'engine_id': 'renderer'},
            {'scene_id': 'middle', 'mode': 'provider', 'provider_id': 'cloud'},
          ],
          productionScenes: _productionScenes,
          productionSpec: _productionSpec,
          assemblyEngineId: 'compositor',
          audioPolicy: 'guess',
        ),
        throwsA(isA<HybridWorkflowSpecException>()),
      );
    });
  });
}
