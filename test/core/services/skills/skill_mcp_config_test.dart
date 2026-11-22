import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/skills/skill_mcp_config.dart';

void main() {
  group('SkillMcpConfigParser', () {
    test('parses stdio metadata without retaining environment values', () {
      final servers = SkillMcpConfigParser.parse('''
{"mcpServers":{"youtube-tools":{"command":"node","args":["server.js","--stdio"],"env":{"YOUTUBE_API_KEY":"\${YOUTUBE_API_KEY}","LOG_LEVEL":""}}}}
''');
      expect(servers, hasLength(1));
      final server = servers.single;
      expect(server.name, 'youtube-tools');
      expect(server.transport, SkillMcpTransport.stdio);
      expect(server.command, 'node');
      expect(server.arguments, ['server.js', '--stdio']);
      expect(server.requiredEnvironmentVariables, ['LOG_LEVEL', 'YOUTUBE_API_KEY']);
      expect(server.requiresManualApproval, isTrue);
      expect(server.executionSupported, isFalse);
    });

    test('rejects literal environment values instead of importing possible secrets', () {
      expect(
        () => SkillMcpConfigParser.parse('{"mcpServers":{"private":{"command":"node","env":{"API_KEY":"secret-value"}}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('literal_skill_mcp_environment_value_requires_secure_setup'))),
      );
    });

    test('rejects command strings that could contain shell fragments', () {
      expect(
        () => SkillMcpConfigParser.parse('{"mcpServers":{"bad":{"command":"node;sh","args":[]}}}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid argument arrays and NUL values', () {
      expect(
        () => SkillMcpConfigParser.parse('{"mcpServers":{"bad":{"command":"node","args":[1]}}}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SkillMcpConfigParser.parse('{"mcpServers":{"bad":{"command":"node","args":["bad\u0000arg"]}}}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts only clean HTTPS remote endpoints and keeps them non-executable', () {
      final servers = SkillMcpConfigParser.parse('{"mcpServers":{"remote":{"type":"streamableHttp","url":"https://mcp.example.com/v1"}}}');
      expect(servers.single.transport, SkillMcpTransport.http);
      expect(servers.single.url!.host, 'mcp.example.com');
      expect(servers.single.executionSupported, isFalse);
    });

    test('rejects insecure or credential-bearing remote endpoints', () {
      for (final url in [
        'http://mcp.example.com',
        'https://user:password@mcp.example.com',
        'https://mcp.example.com?token=secret',
        'https://mcp.example.com/#fragment',
      ]) {
        expect(
          () => SkillMcpConfigParser.parse('{"mcpServers":{"remote":{"type":"http","url":"$url"}}}'),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects imported remote authentication headers', () {
      expect(
        () => SkillMcpConfigParser.parse('{"mcpServers":{"remote":{"type":"sse","url":"https://mcp.example.com/events","headers":{"Authorization":"Bearer secret"}}}}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing config, invalid JSON and unsafe config paths', () {
      expect(() => SkillMcpConfigParser.parse('{"servers":{}}'), throwsA(isA<FormatException>()));
      expect(() => SkillMcpConfigParser.parse('{'), throwsA(isA<FormatException>()));
      expect(
        () => SkillMcpConfigParser.parse('{"mcpServers":{"ok":{"command":"node"}}}', configPath: '../mcp.json'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
