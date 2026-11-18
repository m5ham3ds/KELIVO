import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_tools.dart';

void main() {
  test('Runtime Profile tool exposes snapshot lifecycle with explicit isolation limits', () {
    final definition = RuntimeProfileToolCatalog.definitions().single['function']
        as Map<String, dynamic>;
    final parameters = definition['parameters'] as Map<String, dynamic>;
    final properties = parameters['properties'] as Map<String, dynamic>;
    final actions = (properties['action'] as Map<String, dynamic>)['enum'] as List;

    expect(actions, containsAll([
      'snapshot',
      'snapshots',
      'restore_snapshot',
      'delete_snapshot',
    ]));
    expect(properties, contains('snapshot_id'));
    expect(properties, contains('description'));
    expect(definition['description'], contains('apt/apk'));
  });
}
