import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/video_providers/video_provider_credential_store.dart';

void main() {
  group('MemoryVideoProviderCredentialStore', () {
    late MemoryVideoProviderCredentialStore store;

    setUp(() => store = MemoryVideoProviderCredentialStore());

    test('isolates credentials by Workspace and provider', () async {
      await store.write(
        workspaceId: 'workspace-a',
        providerId: 'provider-a',
        apiKey: '  secret-a  ',
      );
      await store.write(
        workspaceId: 'workspace-b',
        providerId: 'provider-a',
        apiKey: 'secret-b',
      );

      expect(await store.read(workspaceId: 'workspace-a', providerId: 'provider-a'), 'secret-a');
      expect(await store.read(workspaceId: 'workspace-b', providerId: 'provider-a'), 'secret-b');
      expect(await store.has(workspaceId: 'workspace-a', providerId: 'provider-b'), isFalse);
    });

    test('clears only the selected credential scope', () async {
      await store.write(workspaceId: 'ws', providerId: 'one', apiKey: 'one-key');
      await store.write(workspaceId: 'ws', providerId: 'two', apiKey: 'two-key');

      await store.clear(workspaceId: 'ws', providerId: 'one');

      expect(await store.has(workspaceId: 'ws', providerId: 'one'), isFalse);
      expect(await store.read(workspaceId: 'ws', providerId: 'two'), 'two-key');
    });

    test('rejects empty, oversized, and control-character keys', () async {
      for (final key in ['', '   ', 'bad\nkey', List.filled(4097, 'x').join()]) {
        await expectLater(
          store.write(workspaceId: 'ws', providerId: 'p', apiKey: key),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });
}
