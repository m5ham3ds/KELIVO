/// A Plugin child is stored as metadata only. The descriptor never grants
/// permission to execute the referenced file.
final class PluginComponentDescriptor {
  const PluginComponentDescriptor({
    required this.kind,
    required this.name,
    required this.relativePath,
    required this.status,
    required this.digest,
    required this.sizeBytes,
  });

  static const allowedStatuses = <String>{
    'inspect_only',
    'disabled_by_default',
    'unsupported',
  };

  final String kind;
  final String name;
  final String relativePath;
  final String status;
  final String digest;
  final int sizeBytes;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'name': name,
    'relativePath': relativePath,
    'status': status,
    'digest': digest,
    'sizeBytes': sizeBytes,
  };

  factory PluginComponentDescriptor.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('plugin_component_descriptor');
    }
    final map = Map<String, Object?>.from(value);
    final kind = map['kind'];
    final name = map['name'];
    final relativePath = map['relativePath'];
    final status = map['status'];
    final digest = map['digest'];
    final sizeBytes = map['sizeBytes'];
    if (kind is! String ||
        !RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(kind) ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 160 ||
        relativePath is! String ||
        relativePath.length > 2048 ||
        !_isSafePluginRelativePath(relativePath) ||
        status is! String ||
        !allowedStatuses.contains(status) ||
        digest is! String ||
        !RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(digest) ||
        sizeBytes is! int ||
        sizeBytes < 0) {
      throw const FormatException('plugin_component_descriptor_invalid');
    }
    return PluginComponentDescriptor(
      kind: kind,
      name: name,
      relativePath: relativePath,
      status: status,
      digest: digest,
      sizeBytes: sizeBytes,
    );
  }
}

bool _isSafePluginRelativePath(String value) {
  if (value.isEmpty ||
      value.startsWith('/') ||
      value.contains(String.fromCharCode(92)) ||
      value.contains(':') ||
      value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
    return false;
  }
  final parts = value.split('/');
  return parts.every(
    (part) => part.isNotEmpty && part != '.' && part != '..',
  );
}
