import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class VideoProviderCredentialStore {
  Future<String?> read({required String workspaceId, required String providerId});
  Future<void> write({
    required String workspaceId,
    required String providerId,
    required String apiKey,
  });
  Future<void> clear({required String workspaceId, required String providerId});
  Future<bool> has({required String workspaceId, required String providerId});
}

/// Android Keystore-backed API-key storage. Only a deterministic opaque key
/// name is persisted; credentials never enter extension records or manifests.
final class SecureVideoProviderCredentialStore
    implements VideoProviderCredentialStore {
  SecureVideoProviderCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _storageKey(String workspaceId, String providerId) {
    _validateCredentialScope(workspaceId, providerId);
    final scope = sha256.convert(utf8.encode(jsonEncode([workspaceId, providerId])));
    return 'kelivo.video_provider.v1.${scope.toString()}';
  }

  @override
  Future<String?> read({required String workspaceId, required String providerId}) =>
      _storage.read(key: _storageKey(workspaceId, providerId));

  @override
  Future<void> write({
    required String workspaceId,
    required String providerId,
    required String apiKey,
  }) async {
    final value = apiKey.trim();
    if (value.isEmpty || value.length > 4096 ||
        value.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException('video_provider_api_key_invalid');
    }
    await _storage.write(key: _storageKey(workspaceId, providerId), value: value);
  }

  @override
  Future<void> clear({required String workspaceId, required String providerId}) =>
      _storage.delete(key: _storageKey(workspaceId, providerId));

  @override
  Future<bool> has({required String workspaceId, required String providerId}) async =>
      (await read(workspaceId: workspaceId, providerId: providerId))?.isNotEmpty == true;
}

/// Test implementation. Never selected by application composition.
final class MemoryVideoProviderCredentialStore
    implements VideoProviderCredentialStore {
  final Map<String, String> _values = {};

  String _key(String workspaceId, String providerId) {
    _validateCredentialScope(workspaceId, providerId);
    return jsonEncode([workspaceId, providerId]);
  }

  @override
  Future<String?> read({required String workspaceId, required String providerId}) async =>
      _values[_key(workspaceId, providerId)];

  @override
  Future<void> write({
    required String workspaceId,
    required String providerId,
    required String apiKey,
  }) async {
    final value = apiKey.trim();
    if (value.isEmpty || value.length > 4096 ||
        value.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException('video_provider_api_key_invalid');
    }
    _values[_key(workspaceId, providerId)] = value;
  }

  @override
  Future<void> clear({required String workspaceId, required String providerId}) async {
    _values.remove(_key(workspaceId, providerId));
  }

  @override
  Future<bool> has({required String workspaceId, required String providerId}) async =>
      _values.containsKey(_key(workspaceId, providerId));
}

void _validateCredentialScope(String workspaceId, String providerId) {
  if (workspaceId.isEmpty || workspaceId.length > 128 ||
      workspaceId.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
      !RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(providerId)) {
    throw const FormatException('video_provider_credential_scope_invalid');
  }
}
