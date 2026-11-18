import 'package:path/path.dart' as p;

/// Parsed GitHub repository location with an optional branch, tag, commit or
/// skill subdirectory. A `?ref=` query is supported for refs containing `/`.
class GitHubSkillRef {
  const GitHubSkillRef({
    required this.owner,
    required this.repo,
    this.ref,
    this.subdir,
    this.filePath,
  });

  final String owner;
  final String repo;
  final String? ref;
  final String? subdir;
  /// Exact repository-relative file for direct `.skill` or `.zip` links.
  final String? filePath;

  GitHubSkillRef copyWith({String? ref, String? subdir, String? filePath}) => GitHubSkillRef(
    owner: owner,
    repo: repo,
    ref: ref ?? this.ref,
    subdir: subdir ?? this.subdir,
    filePath: filePath ?? this.filePath,
  );

  static GitHubSkillRef parse(String raw) {
    final parsed = tryParse(raw);
    if (parsed == null) {
      throw const FormatException('Not a supported GitHub skill URL');
    }
    return parsed;
  }

  static GitHubSkillRef? tryParse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'https://$text';

    // Uri normalizes literal dot segments while parsing (for example,
    // `/skills/../outside.skill`), so inspect the original path bytes before
    // constructing a Uri. This also rejects percent-encoded separators and
    // dot segments, including double-encoded forms that an upstream proxy may
    // decode before routing the request.
    if (_hasUnsafeRawPathSegments(text)) return null;

    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty || uri.hasFragment ||
        (uri.hasPort && uri.port != 443)) {
      return null;
    }

    // Credentials and opaque query parameters are never accepted in source
    // URLs. Refs with slashes must be supplied as ?ref=feature/name.
    if (uri.queryParametersAll.keys.any((key) => key != 'ref') ||
        uri.queryParametersAll.values.any((values) => values.length != 1)) {
      return null;
    }
    final queryRef = uri.queryParameters['ref']?.trim();
    if (queryRef != null && !_isSafeRef(queryRef)) return null;

    final host = uri.host.toLowerCase();
    final parts = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (host == 'raw.githubusercontent.com') {
      if (parts.length < 3) return null;
      var refIndex = 2;
      // GitHub's canonical raw links may include refs/heads/ or refs/tags/.
      // Older/raw-compatible links use the branch or tag directly.
      if (parts.length >= 5 &&
          parts[2] == 'refs' &&
          (parts[3] == 'heads' || parts[3] == 'tags')) {
        refIndex = 4;
      }
      final ref = queryRef ?? parts[refIndex];
      if (!_isSafeRef(ref)) return null;
      final filePath = parts.skip(refIndex + 1).join('/');
      final directFile = _isDirectSkillFile(filePath) ?
          _requireSafeSubdir(filePath) : null;
      return GitHubSkillRef(
        owner: parts[0],
        repo: _stripGitSuffix(parts[1]),
        ref: ref,
        subdir: directFile == null ? _subdirFromFilePath(filePath) : null,
        filePath: directFile,
      )._validated();
    }
    if (host != 'github.com' && host != 'www.github.com') return null;
    if (parts.length < 2) return null;
    final owner = parts[0];
    final repo = _stripGitSuffix(parts[1]);
    if (!_isSafeRepositoryPart(owner) || !_isSafeRepositoryPart(repo)) {
      return null;
    }
    if (parts.length == 2) {
      return GitHubSkillRef(
        owner: owner,
        repo: repo,
        ref: queryRef,
      );
    }
    final kind = parts[2];
    if (kind != 'tree' && kind != 'blob' && kind != 'raw') {
      // Ignore GitHub UI suffixes such as /issues or /pull; these are not
      // accepted as Skill source paths.
      return null;
    }
    if (parts.length < 4) return null;
    final pathRef = parts[3];
    final ref = queryRef ?? pathRef;
    if (!_isSafeRef(ref)) return null;
    final rest = parts.skip(4).join('/');
    final directFile = kind != 'tree' && _isDirectSkillFile(rest)
        ? _requireSafeSubdir(rest)
        : null;
    final subdir = kind == 'tree'
        ? (rest.isEmpty ? null : _requireSafeSubdir(rest))
        : directFile == null ? _subdirFromFilePath(rest) : null;
    return GitHubSkillRef(
      owner: owner,
      repo: repo,
      ref: ref,
      subdir: subdir,
      filePath: directFile,
    )._validated();
  }

  GitHubSkillRef _validated() {
    if (!_isSafeRepositoryPart(owner) ||
        !_isSafeRepositoryPart(repo) ||
        (ref != null && !_isSafeRef(ref!)) ||
        (subdir != null && _safeSubdir(subdir!) != subdir) ||
        (filePath != null && _safeSubdir(filePath!) != filePath)) {
      throw const FormatException('Unsafe GitHub skill reference');
    }
    return this;
  }
}


/// Checks path segments in the original URL string before `Uri` can normalize
/// dot segments. Only traversal-relevant escapes are decoded so ordinary
/// percent-encoded filenames (for example `%20`) remain supported.
bool _hasUnsafeRawPathSegments(String value) {
  final schemeSeparator = value.indexOf('://');
  if (schemeSeparator < 0) return true;

  final authorityStart = schemeSeparator + 3;
  var pathStart = -1;
  for (var i = authorityStart; i < value.length; i++) {
    final char = value[i];
    if (char == '/') {
      pathStart = i;
      break;
    }
    if (char == '?' || char == '#') return false;
    // Backslashes are not valid URL path separators, but several URL parsers
    // and proxies treat them as slashes. Never allow one in the authority.
    if (char == r'\') return true;
  }
  if (pathStart < 0) return false;

  var pathEnd = value.length;
  final queryIndex = value.indexOf('?', pathStart);
  final fragmentIndex = value.indexOf('#', pathStart);
  if (queryIndex >= 0 && queryIndex < pathEnd) pathEnd = queryIndex;
  if (fragmentIndex >= 0 && fragmentIndex < pathEnd) pathEnd = fragmentIndex;

  final rawPath = value.substring(pathStart, pathEnd);
  if (!rawPath.startsWith('/') || rawPath.contains(r'\') ||
      rawPath.contains('\u0000')) {
    return true;
  }

  final rawSegments = rawPath.substring(1).split('/');
  final traversalEscape = RegExp(r'%(?:25|2e|2f|5c|00)', caseSensitive: false);
  for (var index = 0; index < rawSegments.length; index++) {
    final originalSegment = rawSegments[index];
    // A single trailing slash is harmless, but empty interior segments make
    // path interpretation inconsistent across URL parsers and proxies.
    if (originalSegment.isEmpty) {
      if (index == rawSegments.length - 1) continue;
      return true;
    }

    var segment = originalSegment;
    for (var pass = 0; pass < 8; pass++) {
      final decoded = segment.replaceAllMapped(traversalEscape, (match) {
        final token = match.group(0)!.toLowerCase();
        return switch (token) {
          '%25' => '%',
          '%2e' => '.',
          '%2f' => '/',
          '%5c' => r'\',
          '%00' => '\u0000',
          _ => token,
        };
      });
      if (decoded == segment) break;
      segment = decoded;
      if (segment == '.' || segment == '..' ||
          segment.contains('/') || segment.contains(r'\') ||
          segment.contains('\u0000')) {
        return true;
      }
      // Bound recursive decoding. If another traversal-relevant escape is
      // still present after eight rounds, reject rather than guess.
      if (pass == 7 && traversalEscape.hasMatch(segment)) return true;
    }

    if (segment == '.' || segment == '..' ||
        segment.contains('/') || segment.contains(r'\') ||
        segment.contains('\u0000')) {
      return true;
    }
  }
  return false;
}

bool _isSafeRepositoryPart(String value) =>
    RegExp(r'^[A-Za-z0-9_.-]{1,100}$').hasMatch(value) &&
    value != '.' && value != '..';

bool _isSafeRef(String value) =>
    value.isNotEmpty &&
    value.length <= 200 &&
    !value.startsWith('/') &&
    !value.endsWith('/') &&
    !value.contains('..') &&
    !value.contains('\\') &&
    !value.contains('\u0000') &&
    !value.split('/').any((part) =>
        part.isEmpty || part == '.' || part == '..');

String? _safeSubdir(String value) {
  final normalized = value.replaceAll('\\', '/');
  if (normalized.isEmpty ||
      normalized.startsWith('/') ||
      normalized.contains('\u0000') ||
      normalized.split('/').any(
        (part) => part.isEmpty || part == '.' || part == '..',
      )) {
    return null;
  }
  final result = p.posix.normalize(normalized);
  if (result == '.' || result.startsWith('../') || result.startsWith('/')) {
    return null;
  }
  return result;
}

String _requireSafeSubdir(String value) =>
    _safeSubdir(value) ??
    (throw const FormatException('Unsafe GitHub skill subdirectory'));

String _stripGitSuffix(String repo) =>
    repo.endsWith('.git') ? repo.substring(0, repo.length - 4) : repo;

bool _isDirectSkillFile(String path) {
  final extension = p.posix.extension(path).toLowerCase();
  return path.isNotEmpty && (extension == '.skill' || extension == '.zip');
}

String? _subdirFromFilePath(String filePath) {
  if (filePath.isEmpty) return null;
  final posix = filePath.replaceAll('\\', '/');
  if (posix.startsWith('/') ||
      posix.contains('\u0000') ||
      posix.split('/').any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw const FormatException('Unsafe GitHub Skill file path');
  }
  final dir = p.posix.dirname(posix);
  if (dir == '.' || dir == '/') return null;
  return _requireSafeSubdir(dir);
}
