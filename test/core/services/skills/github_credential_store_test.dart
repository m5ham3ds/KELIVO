import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/skills/github_credential_store.dart';

void main() {
  test('memory credential store reads, replaces and clears tokens', () async {
    final store = MemoryGitHubCredentialStore();
    expect(await store.readToken(), isNull);
    await store.writeToken('ghp_test_private_read_token_123456');
    expect(await store.readToken(), 'ghp_test_private_read_token_123456');
    await store.writeToken('github_pat_replacement_token_123456');
    expect(await store.readToken(), 'github_pat_replacement_token_123456');
    await store.clearToken();
    expect(await store.readToken(), isNull);
  });
}
