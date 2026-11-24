import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/api/providers/google_common.dart';

void main() {
  test('zero Gemini Free Tier quota explains model availability instead of key use', () {
    final body = jsonEncode({
      'error': {
        'code': 429,
        'status': 'RESOURCE_EXHAUSTED',
        'message':
            'Quota exceeded for metric generate_content_free_tier_requests. '
            'limit: 0 for Free Tier model gemini-4-carbon.',
        'details': [
          {
            '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
            'violations': [
              {
                'description':
                    'Generate content requests per day limit exceeded on Free Tier.',
                'quotaMetric':
                    'generativelanguage.googleapis.com/generate_content_free_tier_requests',
                'quotaDimensions': {
                  'location': 'global',
                  'model': 'gemini-4-carbon',
                },
              },
            ],
          },
        ],
      },
    });
    final message = googleApiHttpErrorMessage(
      statusCode: 429,
      errorBody: body,
      modelId: 'gemini-4-carbon',
    );
    expect(message, contains('zero Free Tier quota'));
    expect(message, contains('gemini-4-carbon'));
    expect(message, contains('gemini-4-hydrogen'));
    expect(message, contains('not evidence that someone else used your API key'));
    expect(message, contains('https://aistudio.google.com/docs/pricing'));
  });

  test('ordinary Gemini 429 retains its original response body', () {
    const body = '{"error":{"code":429,"message":"Too many requests"}}';
    expect(
      googleApiHttpErrorMessage(
        statusCode: 429,
        errorBody: body,
        modelId: 'gemini-2.5-flash',
      ),
      'HTTP 429: $body',
    );
  });
}
