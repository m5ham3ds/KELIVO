import 'package:yaml/yaml.dart';

const String kVideoProviderManifestFile = 'kelivo.video-provider.yaml';

final class VideoProviderManifestException implements Exception {
  const VideoProviderManifestException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// Declarative REST connector contract for an external AI video-generation API.
///
/// A connector contains no executable code. Kelivo builds the small set of
/// supported JSON requests itself, injects credentials from secure storage,
/// and validates every endpoint and returned download URL.
final class VideoProviderManifest {
  const VideoProviderManifest({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.baseUri,
    required this.apiKeyRequired,
    required this.apiKeyHeader,
    required this.apiKeyPrefix,
    required this.supportsTextToVideo,
    required this.supportsImageToVideo,
    required this.maxPromptCharacters,
    required this.maxDurationSeconds,
    required this.maxDownloadBytes,
    required this.downloadHosts,
    required this.models,
    required this.defaultModel,
    required this.submit,
    required this.poll,
    this.quote,
  });

  final int schemaVersion;
  final String id;
  final String name;
  final String version;
  final String description;
  final Uri baseUri;
  final bool apiKeyRequired;
  final String apiKeyHeader;
  final String apiKeyPrefix;
  final bool supportsTextToVideo;
  final bool supportsImageToVideo;
  final int maxPromptCharacters;
  final int maxDurationSeconds;
  final int maxDownloadBytes;
  final List<String> downloadHosts;
  final List<String> models;
  final String? defaultModel;
  final VideoProviderSubmitEndpoint submit;
  final VideoProviderPollEndpoint poll;
  final VideoProviderQuoteEndpoint? quote;

  bool get supportsQuotes => quote != null;

  factory VideoProviderManifest.parse(String source) {
    if (source.isEmpty || source.length > 64 * 1024) {
      throw const VideoProviderManifestException('provider_manifest_size_invalid');
    }
    final Object? decoded;
    try {
      decoded = _toPlain(loadYaml(source));
    } on Object {
      throw const VideoProviderManifestException('provider_manifest_yaml_invalid');
    }
    final root = _map(decoded, 'root');
    _onlyKeys(root, const {
      'schemaVersion', 'id', 'name', 'version', 'description', 'api',
      'capabilities', 'models', 'defaultModel', 'limits', 'downloadHosts',
      'endpoints',
    }, 'root');
    if (root['schemaVersion'] != 1) {
      throw const VideoProviderManifestException('provider_manifest_schema_unsupported');
    }
    final id = _requiredString(root, 'id', 64);
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(id)) {
      throw const VideoProviderManifestException('provider_manifest_id_invalid');
    }
    final name = _requiredString(root, 'name', 120);
    final version = _requiredString(root, 'version', 64);
    final description = _requiredString(root, 'description', 1000);

    final api = _map(root['api'], 'api');
    _onlyKeys(api, const {'baseUrl', 'apiKey'}, 'api');
    final baseUri = _publicHttpsUri(_requiredString(api, 'baseUrl', 2048), 'base_url');
    final apiKey = _map(api['apiKey'] ?? const <String, Object?>{}, 'apiKey');
    _onlyKeys(apiKey, const {'required', 'header', 'prefix'}, 'apiKey');
    final keyRequired = _bool(apiKey['required'], fallback: true, field: 'apiKey.required');
    final keyHeader = (apiKey['header'] ?? 'Authorization').toString().trim();
    if (!const {
      'authorization', 'x-api-key', 'api-key', 'x-goog-api-key',
    }.contains(keyHeader.toLowerCase())) {
      throw const VideoProviderManifestException('provider_manifest_api_key_header_invalid');
    }
    final keyPrefix = (apiKey['prefix'] ?? 'Bearer').toString();
    if (!const {'', 'Bearer', 'Token', 'ApiKey'}.contains(keyPrefix)) {
      throw const VideoProviderManifestException('provider_manifest_api_key_prefix_invalid');
    }

    final capabilities = _map(root['capabilities'], 'capabilities');
    _onlyKeys(capabilities, const {'textToVideo', 'imageToVideo'}, 'capabilities');
    final textToVideo = _bool(
      capabilities['textToVideo'], fallback: true, field: 'capabilities.textToVideo',
    );
    final imageToVideo = _bool(
      capabilities['imageToVideo'], fallback: false, field: 'capabilities.imageToVideo',
    );
    if (!textToVideo && !imageToVideo) {
      throw const VideoProviderManifestException('provider_manifest_capability_required');
    }

    final models = _stringList(root['models'] ?? const <Object?>[], 'models', 64, 120);
    final defaultModelValue = root['defaultModel'];
    if (defaultModelValue != null && defaultModelValue is! String) {
      throw const VideoProviderManifestException('provider_manifest_default_model_invalid');
    }
    final defaultModel = (defaultModelValue as String?)?.trim();
    if (defaultModel != null && defaultModel.isNotEmpty &&
        models.isNotEmpty && !models.contains(defaultModel)) {
      throw const VideoProviderManifestException('provider_manifest_default_model_unknown');
    }

    final limits = _map(root['limits'] ?? const <String, Object?>{}, 'limits');
    _onlyKeys(limits, const {
      'maxPromptCharacters', 'maxDurationSeconds', 'maxDownloadBytes',
    }, 'limits');
    final maxPromptCharacters = _integer(
      limits['maxPromptCharacters'], fallback: 12000,
      min: 1, max: 12000, field: 'limits.maxPromptCharacters',
    );
    final maxDurationSeconds = _integer(
      limits['maxDurationSeconds'], fallback: 180,
      min: 1, max: 3600, field: 'limits.maxDurationSeconds',
    );
    final maxDownloadBytes = _integer(
      limits['maxDownloadBytes'], fallback: 128 * 1024 * 1024,
      min: 1024 * 1024, max: 256 * 1024 * 1024,
      field: 'limits.maxDownloadBytes',
    );
    final downloadHosts = _stringList(
      root['downloadHosts'] ?? const <Object?>[], 'downloadHosts', 32, 253,
    ).map((host) => _validateHost(host, 'download_host')).toSet().toList()..sort();

    final endpoints = _map(root['endpoints'], 'endpoints');
    _onlyKeys(endpoints, const {'submit', 'poll', 'quote'}, 'endpoints');
    final submit = VideoProviderSubmitEndpoint.parse(endpoints['submit']);
    final poll = VideoProviderPollEndpoint.parse(endpoints['poll']);
    if (textToVideo && submit.fields.prompt == null) {
      throw const VideoProviderManifestException('provider_manifest_prompt_field_required');
    }
    if (imageToVideo && submit.fields.imageUrl == null) {
      throw const VideoProviderManifestException('provider_manifest_image_field_required');
    }
    final requestFieldPaths = <String?>[
      submit.fields.model,
      submit.fields.prompt,
      submit.fields.imageUrl,
      submit.fields.durationSeconds,
      submit.fields.aspectRatio,
    ].whereType<String>().toList();
    for (var index = 0; index < requestFieldPaths.length; index++) {
      for (var other = index + 1; other < requestFieldPaths.length; other++) {
        final left = requestFieldPaths[index];
        final right = requestFieldPaths[other];
        if (left == right || left.startsWith('$right.') || right.startsWith('$left.')) {
          throw const VideoProviderManifestException('provider_manifest_request_field_conflict');
        }
      }
    }
    final quote = endpoints['quote'] == null
        ? null
        : VideoProviderQuoteEndpoint.parse(endpoints['quote']);

    return VideoProviderManifest(
      schemaVersion: 1,
      id: id,
      name: name,
      version: version,
      description: description,
      baseUri: baseUri,
      apiKeyRequired: keyRequired,
      apiKeyHeader: keyHeader,
      apiKeyPrefix: keyPrefix,
      supportsTextToVideo: textToVideo,
      supportsImageToVideo: imageToVideo,
      maxPromptCharacters: maxPromptCharacters,
      maxDurationSeconds: maxDurationSeconds,
      maxDownloadBytes: maxDownloadBytes,
      downloadHosts: List.unmodifiable(downloadHosts),
      models: List.unmodifiable(models),
      defaultModel: defaultModel?.isEmpty == true ? null : defaultModel,
      submit: submit,
      poll: poll,
      quote: quote,
    );
  }

  bool allowsDownloadHost(String host) =>
      host.toLowerCase() == baseUri.host.toLowerCase() ||
      downloadHosts.contains(host.toLowerCase());

  Map<String, Object?> toSummaryJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'baseHost': baseUri.host,
    'capabilities': {
      'textToVideo': supportsTextToVideo,
      'imageToVideo': supportsImageToVideo,
    },
    'models': models,
    if (defaultModel != null) 'defaultModel': defaultModel,
    'limits': {
      'maxPromptCharacters': maxPromptCharacters,
      'maxDurationSeconds': maxDurationSeconds,
      'maxDownloadBytes': maxDownloadBytes,
    },
    'supportsQuotes': supportsQuotes,
  };
}

final class VideoProviderRequestFields {
  const VideoProviderRequestFields({
    this.model,
    this.prompt,
    this.imageUrl,
    this.durationSeconds,
    this.aspectRatio,
  });

  final String? model;
  final String? prompt;
  final String? imageUrl;
  final String? durationSeconds;
  final String? aspectRatio;

  factory VideoProviderRequestFields.parse(Object? raw) {
    final map = _map(raw, 'fields');
    _onlyKeys(map, const {
      'model', 'prompt', 'imageUrl', 'durationSeconds', 'aspectRatio',
    }, 'fields');
    String? field(String key) {
      final value = map[key];
      if (value == null) return null;
      if (value is! String) {
        throw VideoProviderManifestException('provider_manifest_field_invalid:$key');
      }
      return _jsonFieldPath(value, 'fields.$key');
    }
    return VideoProviderRequestFields(
      model: field('model'),
      prompt: field('prompt'),
      imageUrl: field('imageUrl'),
      durationSeconds: field('durationSeconds'),
      aspectRatio: field('aspectRatio'),
    );
  }
}

final class VideoProviderSubmitEndpoint {
  const VideoProviderSubmitEndpoint({
    required this.path,
    required this.jobIdPath,
    required this.fields,
  });

  final String path;
  final String jobIdPath;
  final VideoProviderRequestFields fields;

  factory VideoProviderSubmitEndpoint.parse(Object? raw) {
    final map = _map(raw, 'submit');
    _onlyKeys(map, const {'path', 'jobIdPath', 'fields'}, 'submit');
    return VideoProviderSubmitEndpoint(
      path: _endpointPath(_requiredString(map, 'path', 512), allowJobId: false),
      jobIdPath: _jsonFieldPath(_requiredString(map, 'jobIdPath', 256), 'submit.jobIdPath'),
      fields: VideoProviderRequestFields.parse(map['fields']),
    );
  }
}

final class VideoProviderPollEndpoint {
  const VideoProviderPollEndpoint({
    required this.path,
    required this.statusPath,
    required this.outputUrlPath,
    required this.queuedStatuses,
    required this.runningStatuses,
    required this.succeededStatuses,
    required this.failedStatuses,
    this.errorPath,
    this.progressPath,
    this.costPath,
  });

  final String path;
  final String statusPath;
  final String outputUrlPath;
  final String? errorPath;
  final String? progressPath;
  final String? costPath;
  final List<String> queuedStatuses;
  final List<String> runningStatuses;
  final List<String> succeededStatuses;
  final List<String> failedStatuses;

  factory VideoProviderPollEndpoint.parse(Object? raw) {
    final map = _map(raw, 'poll');
    _onlyKeys(map, const {
      'path', 'statusPath', 'outputUrlPath', 'errorPath', 'progressPath',
      'costPath', 'statuses',
    }, 'poll');
    final statuses = _map(map['statuses'], 'poll.statuses');
    _onlyKeys(statuses, const {'queued', 'running', 'succeeded', 'failed'}, 'poll.statuses');
    final queued = _stringList(statuses['queued'] ?? const ['queued', 'pending'], 'statuses.queued', 32, 64);
    final running = _stringList(statuses['running'] ?? const ['processing', 'running'], 'statuses.running', 32, 64);
    final succeeded = _stringList(statuses['succeeded'] ?? const ['completed', 'succeeded', 'success'], 'statuses.succeeded', 32, 64);
    final failed = _stringList(statuses['failed'] ?? const ['failed', 'error', 'cancelled', 'canceled'], 'statuses.failed', 32, 64);
    final normalizedQueued = queued.map((value) => value.toLowerCase()).toList();
    final normalizedRunning = running.map((value) => value.toLowerCase()).toList();
    final normalizedSucceeded = succeeded.map((value) => value.toLowerCase()).toList();
    final normalizedFailed = failed.map((value) => value.toLowerCase()).toList();
    final all = <String>{
      ...normalizedQueued, ...normalizedRunning,
      ...normalizedSucceeded, ...normalizedFailed,
    };
    if (all.length != queued.length + running.length + succeeded.length + failed.length) {
      throw const VideoProviderManifestException('provider_manifest_status_duplicate');
    }
    String? optionalPath(String key) {
      final value = map[key];
      if (value == null) return null;
      if (value is! String) {
        throw VideoProviderManifestException('provider_manifest_poll_path_invalid:$key');
      }
      return _jsonFieldPath(value, 'poll.$key');
    }
    return VideoProviderPollEndpoint(
      path: _endpointPath(_requiredString(map, 'path', 512), allowJobId: true),
      statusPath: _jsonFieldPath(_requiredString(map, 'statusPath', 256), 'poll.statusPath'),
      outputUrlPath: _jsonFieldPath(_requiredString(map, 'outputUrlPath', 256), 'poll.outputUrlPath'),
      errorPath: optionalPath('errorPath'),
      progressPath: optionalPath('progressPath'),
      costPath: optionalPath('costPath'),
      queuedStatuses: List.unmodifiable(normalizedQueued),
      runningStatuses: List.unmodifiable(normalizedRunning),
      succeededStatuses: List.unmodifiable(normalizedSucceeded),
      failedStatuses: List.unmodifiable(normalizedFailed),
    );
  }
}

final class VideoProviderQuoteEndpoint {
  const VideoProviderQuoteEndpoint({
    required this.path,
    required this.costPath,
    required this.currency,
  });

  final String path;
  final String costPath;
  final String currency;

  factory VideoProviderQuoteEndpoint.parse(Object? raw) {
    final map = _map(raw, 'quote');
    _onlyKeys(map, const {'path', 'costPath', 'currency'}, 'quote');
    final currency = _requiredString(map, 'currency', 3).toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const VideoProviderManifestException('provider_manifest_quote_currency_invalid');
    }
    return VideoProviderQuoteEndpoint(
      path: _endpointPath(_requiredString(map, 'path', 512), allowJobId: false),
      costPath: _jsonFieldPath(_requiredString(map, 'costPath', 256), 'quote.costPath'),
      currency: currency,
    );
  }
}

Map<String, Object?> _map(Object? raw, String field) {
  if (raw is! Map || raw.keys.any((key) => key is! String)) {
    throw VideoProviderManifestException('provider_manifest_object_invalid:$field');
  }
  return {for (final entry in raw.entries) entry.key as String: entry.value};
}

void _onlyKeys(Map<String, Object?> map, Set<String> allowed, String field) {
  if (map.keys.any((key) => !allowed.contains(key))) {
    throw VideoProviderManifestException('provider_manifest_unknown_field:$field');
  }
}

String _requiredString(Map<String, Object?> map, String key, int max) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty || value.length > max ||
      _hasControl(value)) {
    throw VideoProviderManifestException('provider_manifest_string_invalid:$key');
  }
  return value.trim();
}

bool _bool(Object? value, {required bool fallback, required String field}) {
  if (value == null) return fallback;
  if (value is! bool) throw VideoProviderManifestException('provider_manifest_bool_invalid:$field');
  return value;
}

int _integer(
  Object? value, {
  required int fallback,
  required int min,
  required int max,
  required String field,
}) {
  if (value == null) return fallback;
  if (value is! int || value < min || value > max) {
    throw VideoProviderManifestException('provider_manifest_integer_invalid:$field');
  }
  return value;
}

List<String> _stringList(Object? raw, String field, int maxItems, int maxLength) {
  if (raw is! List || raw.length > maxItems || raw.any((item) => item is! String)) {
    throw VideoProviderManifestException('provider_manifest_list_invalid:$field');
  }
  final values = raw.cast<String>().map((e) => e.trim()).toList();
  if (values.any((e) => e.isEmpty || e.length > maxLength || _hasControl(e)) ||
      values.toSet().length != values.length) {
    throw VideoProviderManifestException('provider_manifest_list_item_invalid:$field');
  }
  return values;
}

String _jsonFieldPath(String value, String field) {
  if (value.length > 256 ||
      !RegExp(r'^[A-Za-z0-9_-]{1,64}(?:\.[A-Za-z0-9_-]{1,64})*$').hasMatch(value)) {
    throw VideoProviderManifestException('provider_manifest_json_path_invalid:$field');
  }
  return value;
}

String _endpointPath(String value, {required bool allowJobId}) {
  if (value.length > 512 || !value.startsWith('/') ||
      value.contains('?') || value.contains('#') || value.contains('\\') ||
      value.contains('%') || _hasControl(value)) {
    throw const VideoProviderManifestException('provider_manifest_endpoint_path_invalid');
  }
  final placeholderPattern = RegExp(r'\{[^{}]+\}');
  final placeholders = placeholderPattern.allMatches(value).map((m) => m.group(0)).toList();
  if (placeholders.any((item) => item != '{job_id}') ||
      (!allowJobId && placeholders.isNotEmpty) ||
      (allowJobId && placeholders.length != 1)) {
    throw const VideoProviderManifestException('provider_manifest_endpoint_placeholder_invalid');
  }
  final withoutPlaceholder = value.replaceAll('{job_id}', 'job-id');
  if (withoutPlaceholder != '/' &&
      withoutPlaceholder.substring(1).split('/').any(
        (part) => part.isEmpty || part == '.' || part == '..',
      )) {
    throw const VideoProviderManifestException('provider_manifest_endpoint_path_invalid');
  }
  return value;
}

Uri _publicHttpsUri(String raw, String field) {
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' || !uri.hasAuthority ||
      uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.hasQuery ||
      uri.hasFragment || uri.port != 443 ||
      uri.path.isNotEmpty && uri.path != '/') {
    throw VideoProviderManifestException('provider_manifest_https_url_invalid:$field');
  }
  _validateHost(uri.host, field);
  return uri.replace(path: uri.path.isEmpty ? '/' : uri.path);
}

String _validateHost(String value, String field) {
  final host = value.toLowerCase();
  if (host.length > 253 || host.isEmpty || host == 'localhost' ||
      host.endsWith('.localhost') || host.endsWith('.local') ||
      host.contains(':') || RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$').hasMatch(host) ||
      !RegExp(r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$').hasMatch(host)) {
    throw VideoProviderManifestException('provider_manifest_host_invalid:$field');
  }
  return host;
}

bool _hasControl(String value) =>
    value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);

Object? _toPlain(Object? value, [_YamlConversionBudget? budget, int depth = 0]) {
  final state = budget ?? _YamlConversionBudget();
  if (depth > 32 || ++state.nodes > 8192) {
    throw const FormatException('provider_manifest_yaml_complexity_limit');
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('provider_manifest_yaml_string_keys_required');
      }
      final key = entry.key as String;
      if (result.containsKey(key)) {
        throw const FormatException('provider_manifest_yaml_duplicate_key');
      }
      result[key] = _toPlain(entry.value, state, depth + 1);
    }
    return result;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
      value.map((item) => _toPlain(item, state, depth + 1)),
    );
  }
  return value;
}

final class _YamlConversionBudget {
  int nodes = 0;
}
