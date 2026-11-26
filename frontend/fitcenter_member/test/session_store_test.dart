import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/session_store.dart';

class MemoryStore implements SessionStore {
  String? value;
  @override
  String? read() => value;
  @override
  void write(String v) => value = v;
  @override
  void clear() => value = null;
}

http.Response tokens([String role = 'MEMBER']) => http.Response(
  jsonEncode({'role': role, 'accessToken': 'a1', 'refreshToken': 'r1'}),
  200,
);

ApiClient client(SessionStore? store, [MockClientHandler? handler]) =>
    ApiClient(
      expectedRole: 'MEMBER',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient(handler ?? (_) async => tokens()),
      store: store,
    );

void main() {
  test('flag is off unless the build asks for it', () {
    expect(keepSessionOnReload, isFalse);
    expect(tabSessionStore(), isNull); // not a browser in tests
  });

  test('without a store nothing survives a new client', () async {
    await client(null).login('m@fit.test', 'password1');
    expect(client(null).authenticated, isFalse);
  });

  test('with a store a reload stays signed in, password is not kept', () async {
    final store = MemoryStore();
    await client(store).login('m@fit.test', 'password1');
    expect(client(store).authenticated, isTrue);
    expect(store.value, isNot(contains('password1')));
    expect(store.value, isNot(contains('m@fit.test')));
  });

  test('logout forgets the saved session', () async {
    final store = MemoryStore();
    final api = client(store);
    await api.login('m@fit.test', 'password1');
    api.logout();
    expect(store.value, isNull);
    expect(client(store).authenticated, isFalse);
  });

  test('damaged or other-role data is rejected and removed', () {
    for (final bad in [
      'not json',
      '[]',
      '{"role":"ADMIN","accessToken":"a","refreshToken":"r"}',
      '{"role":"MEMBER","accessToken":"","refreshToken":"r"}',
    ]) {
      final store = MemoryStore()..value = bad;
      expect(client(store).authenticated, isFalse, reason: bad);
      expect(store.value, isNull, reason: bad);
    }
  });

  test('a restored session that the server refuses is dropped', () async {
    final store = MemoryStore()
      ..value =
          '{"role":"MEMBER","accessToken":"old","refreshToken":"revoked"}';
    final api = client(store, (_) async => http.Response('{}', 401));
    expect(api.authenticated, isTrue);
    await expectLater(api.request('GET', '/bookings/me'), throwsA(isA<ApiError>()));
    expect(api.authenticated, isFalse);
    expect(store.value, isNull);
  });
}
