import 'package:http/http.dart' as http;

http.Client createMcpOAuthDiscoveryHttpClient() => http.Client();

Future<void> validateMcpOAuthPublicUri(Uri uri) => Future<void>.value();

Future<http.Client> createMcpSkillsPinnedHttpClient(Uri uri) =>
    Future<http.Client>.error(
      UnsupportedError('Pinned Remote Skills HTTP is unavailable on this platform'),
    );
