import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/skills/skill_execution_permissions.dart';

void main() {
  group('SkillExecutionPermissionPolicy', () {
    test('requires only the current local-script adapter permissions', () {
      final review = SkillExecutionPermissionPolicy.reviewForSkill(const []);
      final ids = review.map((item) => item['permission']).toSet();

      expect(
        ids,
        containsAll(SkillExecutionPermissionPolicy.requiredLocalScriptPermissions),
      );
      expect(ids, isNot(contains('workspace.write')));
      expect(
        review.firstWhere((item) => item['permission'] == 'skill.source.read')['enforcement'],
        'staged_readonly_mount_best_effort',
      );
      expect(
        review.firstWhere((item) => item['permission'] == 'network.read')['enforcement'],
        'guest_runtime_unrestricted_manual_approval_only',
      );
      expect(review.every((item) => item['executionGranted'] == false), isTrue);
    });

    test('unsupported known permissions stay blocked for local scripts', () {
      final review = SkillExecutionPermissionPolicy.reviewForSkill([
        'device.location',
      ]);
      final location = review.firstWhere(
        (item) => item['permission'] == 'device.location',
      );

      expect(location['recognized'], isTrue);
      expect(location['blockedUntilReviewed'], isTrue);
      expect(location['blockedReason'], 'permission_requires_native_adapter');
      expect(
        () => SkillExecutionPermissionPolicy.approveForSingleRun(
          review: review,
          grantId: 'test-grant-123456',
        ),
        throwsA(isA<SkillExecutionPermissionException>()),
      );
    });

    test('unknown permissions remain blocked and cannot receive grants', () {
      final review = SkillExecutionPermissionPolicy.reviewForSkill([
        'device.unrestricted_root',
      ]);
      expect(
        review.any((item) => item['permission'] == 'device.unrestricted_root' &&
            item['blockedUntilReviewed'] == true),
        isTrue,
      );
      expect(
        () => SkillExecutionPermissionPolicy.approveForSingleRun(
          review: review,
          grantId: 'test-grant-123456',
        ),
        throwsA(isA<SkillExecutionPermissionException>()),
      );
    });

    test('manual approval creates a grant scoped to one execution id', () {
      const grantId = 'run-grant-123456';
      final pending = SkillExecutionPermissionPolicy.reviewForSkill(const []);
      final approved = SkillExecutionPermissionPolicy.approveForSingleRun(
        review: pending,
        grantId: grantId,
      );

      expect(approved.every((item) => item['executionGranted'] == true), isTrue);
      expect(approved.every((item) => item['grantScope'] == 'single_run'), isTrue);
      expect(approved.every((item) => item['executionGrantId'] == grantId), isTrue);
      expect(
        () => SkillExecutionPermissionPolicy.validateSingleRunGrant(
          permissionReview: approved,
          grantId: grantId,
        ),
        returnsNormally,
      );
      expect(
        () => SkillExecutionPermissionPolicy.validateSingleRunGrant(
          permissionReview: approved,
          grantId: 'other-grant-12345',
        ),
        throwsA(isA<SkillExecutionPermissionException>()),
      );
    });

    test('a single-run grant cannot be replayed after dispatch validation', () {
      const grantId = 'one-time-grant-12345';
      final approved = SkillExecutionPermissionPolicy.approveForSingleRun(
        review: SkillExecutionPermissionPolicy.reviewForSkill(const []),
        grantId: grantId,
      );

      SkillExecutionPermissionPolicy.validateSingleRunGrant(
        permissionReview: approved,
        grantId: grantId,
      );
      expect(
        () => SkillExecutionPermissionPolicy.validateSingleRunGrant(
          permissionReview: approved,
          grantId: grantId,
        ),
        throwsA(isA<SkillExecutionPermissionException>()),
      );
    });

    test('pending review cannot be used as an execution grant', () {
      final pending = SkillExecutionPermissionPolicy.reviewForSkill(const []);
      expect(
        () => SkillExecutionPermissionPolicy.validateSingleRunGrant(
          permissionReview: pending,
          grantId: 'pending-grant-123',
        ),
        throwsA(isA<SkillExecutionPermissionException>()),
      );
    });

    test('policy summary discloses unsupported PRoot boundaries', () {
      final summary = SkillExecutionPermissionPolicy.policySummary();
      expect(summary['grantLifetime'], 'single_run');
      expect(summary['unknownPermissions'], 'blocked');
      final limitations = (summary['limitations'] as List).join(' ');
      expect(limitations, contains('not a kernel sandbox'));
      expect(limitations, contains('shared and writable'));
      expect(limitations, contains('device network'));
    });
  });
}
