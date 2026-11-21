import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_pt/services/api_client.dart';
import 'package:fitcenter_pt/services/booking_service.dart';

void main() {
  for (final status in [200, 201, 500]) {
    test(
      'unexpected/malformed write response $status stays uncertain without retry',
      () async {
        var writes = 0;
        final api = ApiClient(
          expectedRole: 'PT',
          baseUri: Uri.parse('http://localhost/api/v1'),
          client: MockClient((r) async {
            if (r.url.path.endsWith('/login'))
              return http.Response(
                jsonEncode({
                  'role': 'PT',
                  'accessToken': 'test-access',
                  'refreshToken': 'test-refresh',
                }),
                200,
              );
            writes++;
            return http.Response('{}', status);
          }),
        );
        addTearDown(api.dispose);
        await api.login('fixture@example.invalid', 'test-only');
        await expectLater(
          BookingService(api).create(DateTime.utc(2030, 1, 2, 3)),
          throwsA(
            isA<ApiError>().having((e) => e.outcomeUnknown, 'ambiguous', true),
          ),
        );
        expect(writes, 1);
      },
    );
  }
}
