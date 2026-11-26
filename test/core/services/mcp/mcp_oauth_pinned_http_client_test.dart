import 'dart:io';

import 'package:Kelivo/core/services/mcp/mcp_oauth_http_client_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Remote Skills pinned HTTPS client', () {
    test('rejects non-HTTPS, userinfo and fragments before DNS lookup', () async {
      var lookups = 0;
      Future<List<InternetAddress>> lookup(String host) async {
        lookups++;
        return [InternetAddress('8.8.8.8')];
      }

      for (final uri in [
        Uri.parse('http://example.com/mcp'),
        Uri.parse('https://user:secret@example.com/mcp'),
        Uri.parse('https://example.com/mcp#fragment'),
      ]) {
        await expectLater(
          resolveMcpSkillsPinnedAddresses(uri, lookup: lookup),
          throwsA(isA<FormatException>()),
        );
      }
      expect(lookups, 0);
    });

    test('rejects mixed public and private DNS answers fail-closed', () async {
      await expectLater(
        resolveMcpSkillsPinnedAddresses(
          Uri.parse('https://mcp.example.com/mcp'),
          lookup: (_) async => [
            InternetAddress('8.8.8.8'),
            InternetAddress('127.0.0.1'),
          ],
        ),
        throwsA(isA<SocketException>()),
      );
    });

    test('rejects proxy fake-IP DNS answers for Remote Skills', () async {
      await expectLater(
        resolveMcpSkillsPinnedAddresses(
          Uri.parse('https://mcp.example.com/mcp'),
          lookup: (_) async => [InternetAddress('198.18.0.1')],
        ),
        throwsA(isA<SocketException>()),
      );
    });

    test('pins socket connector to validated address snapshot', () async {
      final endpoint = Uri.parse('https://mcp.example.com/mcp');
      final vetted = InternetAddress('8.8.8.8');
      InternetAddress? connectedAddress;
      final client = await createMcpSkillsPinnedHttpClient(
        endpoint,
        lookup: (_) async => [vetted],
        socketConnector: (address, port) async {
          connectedAddress = address;
          throw SocketException('test connection stopped');
        },
      );
      addTearDown(client.close);

      await expectLater(
        client.get(endpoint),
        throwsA(isA<SocketException>()),
      );
      expect(connectedAddress?.address, vetted.address);
    });

    test('refuses cross-origin requests after session construction', () async {
      final endpoint = Uri.parse('https://mcp.example.com/mcp');
      var connectorCalls = 0;
      final client = await createMcpSkillsPinnedHttpClient(
        endpoint,
        lookup: (_) async => [InternetAddress('8.8.8.8')],
        socketConnector: (address, port) async {
          connectorCalls++;
          throw SocketException('unexpected network connection');
        },
      );
      addTearDown(client.close);

      await expectLater(
        client.get(Uri.parse('https://other.example.com/mcp')),
        throwsA(anything),
      );
      expect(connectorCalls, 0);
    });
  });
}
