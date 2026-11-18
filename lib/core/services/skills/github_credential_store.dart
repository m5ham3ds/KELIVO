import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class GitHubCredentialStore {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clearToken();
}

/// Uses Android Keystore-backed encrypted storage. Tokens are never written to
/// Skill records, registry metadata, URLs, logs, or build artifacts.
class SecureGitHubCredentialStore implements GitHubCredentialStore {
  SecureGitHubCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'github.private_skill_read_token.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _key);

  @override
  Future<void> writeToken(String token) => _storage.write(
    key: _key,
    value: token,
  );

  @override
  Future<void> clearToken() => _storage.delete(key: _key);
}

/// Test-only in-memory implementation; production defaults to secure storage.
class MemoryGitHubCredentialStore implements GitHubCredentialStore {
  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async => this.token = token;

  @override
  Future<void> clearToken() async => token = null;
}
