import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/services/api_client.dart';
import 'package:fitcenter_ad/services/vietnam_time.dart';

http.Response tokens([String role = 'ADMIN', String access = 'access-test']) =>
    http.Response(
      jsonEncode({
        'accessToken': access,
        'refreshToken': 'refresh-test',
        'role': role,
      }),
      200,
    );
void main() {
  late ApiClient api;
  tearDown(() => api.dispose());
  test('missing configuration sends nothing', () async {
    api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri(),
      client: MockClient((_) async => throw StateError('Must not send')),
    );
    await expectLater(
      api.login('a@example.invalid', 'test-only'),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'CONFIGURATION')),
    );
  });
  test('login checks role and logout clears memory', () async {
    var role = 'MEMBER';
    api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((_) async => tokens(role)),
    );
    await expectLater(
      api.login('a@example.invalid', 'test-only'),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'ROLE_MISMATCH')),
    );
    expect(api.authenticated, false);
    role = 'ADMIN';
    await api.login('a@example.invalid', 'test-only');
    expect(api.authenticated, true);
    api.logout();
    expect(api.authenticated, false);
    await expectLater(api.request('GET', '/x'), throwsA(isA<ApiError>()));
  });
  test('GET refreshes once and uses new Bearer', () async {
    var reads = 0, refreshes = 0;
    api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return tokens();
        if (r.url.path.endsWith('/refresh')) {
          refreshes++;
          return tokens('ADMIN', 'new-access');
        }
        reads++;
        if (reads == 1) return http.Response('{}', 401);
        expect(r.headers['Authorization'], 'Bearer new-access');
        return http.Response('[]', 200);
      }),
    );
    await api.login('a@example.invalid', 'test-only');
    expect(await api.request('GET', '/x'), []);
    expect(reads, 2);
    expect(refreshes, 1);
  });
  test('second GET 401 logs out without loop', () async {
    var reads = 0, refreshes = 0;
    api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return tokens();
        if (r.url.path.endsWith('/refresh')) {
          refreshes++;
          return tokens();
        }
        reads++;
        return http.Response('{}', 401);
      }),
    );
    await api.login('a@example.invalid', 'test-only');
    await expectLater(api.request('GET', '/x'), throwsA(isA<ApiError>()));
    expect(reads, 2);
    expect(refreshes, 1);
    expect(api.authenticated, false);
  });
  test('concurrent GETs share refresh', () async {
    var refreshes = 0;
    final gate = Completer<http.Response>();
    api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return tokens();
        if (r.url.path.endsWith('/refresh')) {
          refreshes++;
          return gate.future;
        }
        return r.headers['Authorization'] == 'Bearer new-access'
            ? http.Response('[]', 200)
            : http.Response('{}', 401);
      }),
    );
    await api.login('a@example.invalid', 'test-only');
    final reads = [api.request('GET', '/a'), api.request('GET', '/b')];
    await Future<void>.delayed(Duration.zero);
    gate.complete(tokens('ADMIN', 'new-access'));
    await Future.wait(reads);
    expect(refreshes, 1);
  });
  test('logout during refresh cannot restore session', () async {
    final gate = Completer<http.Response>(), entered = Completer<void>();
    api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return tokens();
        if (r.url.path.endsWith('/refresh')) {
          entered.complete();
          return gate.future;
        }
        return http.Response('{}', 401);
      }),
    );
    await api.login('a@example.invalid', 'test-only');
    final checked = expectLater(
      api.request('GET', '/x'),
      throwsA(isA<ApiError>()),
    );
    await entered.future;
    api.logout();
    gate.complete(tokens());
    await checked;
    expect(api.authenticated, false);
  });
  test('PUT 401 refreshes but never replays', () async {
    var writes = 0, refreshes = 0;
    api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return tokens();
        if (r.url.path.endsWith('/refresh')) {
          refreshes++;
          return tokens();
        }
        writes++;
        return http.Response('{}', 401);
      }),
    );
    await api.login('a@example.invalid', 'test-only');
    await expectLater(
      api.request('PUT', '/write'),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', 'SESSION_REFRESHED'),
      ),
    );
    expect(writes, 1);
    expect(refreshes, 1);
  });
  test('network write failure remains ambiguous without retry', () async {
    var writes = 0;
    api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return tokens();
        writes++;
        throw http.ClientException('offline');
      }),
    );
    await api.login('a@example.invalid', 'test-only');
    await expectLater(
      api.request('PUT', '/write'),
      throwsA(isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true)),
    );
    expect(writes, 1);
  });
  test('write timeout is not retried', () async {
    var writes = 0;
    api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      timeout: const Duration(milliseconds: 10),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return tokens();
        writes++;
        return Completer<http.Response>().future;
      }),
    );
    await api.login('a@example.invalid', 'test-only');
    await expectLater(
      api.request('PUT', '/write'),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'NETWORK_TIMEOUT')),
    );
    expect(writes, 1);
  });
  test(
    'nested error and correlation map correctly, URI encodes offsets',
    () async {
      api = ApiClient(
        expectedRole: 'ADMIN',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) return tokens();
          expect(r.url.queryParameters['from'], '2030-01-01T00:00:00+07:00');
          expect(r.url.toString(), contains('%2B07'));
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {
                'code': 'ERR_SLOT_NO_LONGER_AVAILABLE',
                'message': 'Slot unavailable',
                'correlationId': 'test-correlation',
              },
            }),
            409,
          );
        }),
      );
      await api.login('a@example.invalid', 'test-only');
      await expectLater(
        api.request('GET', '/x', query: {'from': '2030-01-01T00:00:00+07:00'}),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'ERR_SLOT_NO_LONGER_AVAILABLE')
              .having(
                (e) => e.correlationId,
                'correlation',
                'test-correlation',
              ),
        ),
      );
    },
  );
  test(
    'Vietnam display and input ignore device timezone and reject date overflow',
    () {
      api = ApiClient(expectedRole: 'ADMIN', baseUri: Uri());
      final start = parseVietnamInput('2030-01-02 10:00');
      expect(start, DateTime.utc(2030, 1, 2, 3));
      expect(vietnamTime(start), '02/01/2030 10:00 (giờ Việt Nam, UTC+07:00)');
      expect(
        () => parseVietnamInput('2030-02-31 10:00'),
        throwsFormatException,
      );
      expect(
        queryRange(start, start.add(const Duration(minutes: 90)))['from'],
        endsWith('Z'),
      );
    },
  );

  test('old read cannot overwrite a different account session', () async {
    final gate = Completer<http.Response>();
    api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return tokens('ADMIN');
        return gate.future;
      }),
    );
    await api.login('a@example.invalid', 'test-only');
    final old = expectLater(
      api.request('GET', '/old'),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')),
    );
    api.logout();
    await api.login('b@example.invalid', 'test-only');
    gate.complete(http.Response('[]', 200));
    await old;
    expect(api.authenticated, true);
  });
}
