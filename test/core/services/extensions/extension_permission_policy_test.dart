import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/extensions/extension_permission_policy.dart';

void main() {
  group('ExtensionPermissionPolicy', () {
    test('sorts and deduplicates permission declarations', () {
      final review = ExtensionPermissionPolicy.review([
        'network.video_generation',
        'workspace.project.read',
        'network.video_generation',
      ]);
      expect(review.map((item) => item['permission']), [
        'network.video_generation',
        'workspace.project.read',
      ]);
    });

    test('classifies network and local execution permissions by risk', () {
      final review = ExtensionPermissionPolicy.review([
        'network.video_generation',
        'runtime.proot.execute',
      ]);
      expect(review[0]['risk'], 'high');
      expect(review[1]['risk'], 'critical');
      expect(review.every((item) => item['requiresExplicitApproval'] == true), isTrue);
      expect(review.every((item) => item['executionGranted'] == false), isTrue);
    });

    test('unknown permissions remain blocked and are never granted', () {
      final review = ExtensionPermissionPolicy.review(['device.root_access']);
      expect(review.single['recognized'], isFalse);
      expect(review.single['risk'], 'unknown');
      expect(review.single['blockedUntilReviewed'], isTrue);
      expect(review.single['executionGranted'], isFalse);
    });

    test('empty declarations produce no implicit grants', () {
      expect(ExtensionPermissionPolicy.review(const []), isEmpty);
    });
  });
}
