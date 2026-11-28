import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/toolset_binding.dart';

void main() {
  group('ToolsetBinding', () {
    test('missing key inherits the assistant selection', () {
      const extras = <String, dynamic>{'unrelated': true};
      final binding = ToolsetBinding.fromExtras(extras);

      expect(binding.toolsetIds, isNull);
      expect(binding.applyTo(extras), extras);
    });

    test('explicit empty list means core-only and round-trips', () {
      const binding = ToolsetBinding(toolsetIds: <String>[]);
      final extras = binding.applyTo(const <String, dynamic>{
        'unrelated': true,
      });

      expect(extras[ToolsetBinding.keyIds], isEmpty);
      expect(ToolsetBinding.fromExtras(extras).toolsetIds, isEmpty);
      expect(extras['unrelated'], isTrue);
    });

    test('explicit selection round-trips without mutating other extras', () {
      const binding = ToolsetBinding(
        toolsetIds: <String>['memory', 'workspace'],
      );
      final extras = binding.applyTo(const <String, dynamic>{
        'workspace.id': 'ws-1',
        'skills.ids': <String>['skill-a'],
      });

      expect(
        ToolsetBinding.fromExtras(extras).toolsetIds,
        <String>['memory', 'workspace'],
      );
      expect(extras['workspace.id'], 'ws-1');
      expect(extras['skills.ids'], <String>['skill-a']);
    });

    test('null removes an existing override and restores inheritance', () {
      final cleared = const ToolsetBinding().applyTo(const <String, dynamic>{
        ToolsetBinding.keyIds: <String>['search'],
        'workspace.id': 'ws-1',
      });

      expect(cleared.containsKey(ToolsetBinding.keyIds), isFalse);
      expect(ToolsetBinding.fromExtras(cleared).toolsetIds, isNull);
      expect(cleared['workspace.id'], 'ws-1');
    });
  });
}
