import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/photo_picker.dart';
import 'package:fitcenter/widgets/avatar.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhWMjWwAAAABJRU5ErkJggg==',
);

http.Response tokens() => http.Response(
  jsonEncode({'role': 'MEMBER', 'accessToken': 'a1', 'refreshToken': 'r1'}),
  200,
);

Future<ApiClient> signedIn(MockClientHandler handler) async {
  final api = ApiClient(
    expectedRole: 'MEMBER',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: MockClient(
      (r) async => r.url.path.endsWith('/auth/login') ? tokens() : handler(r),
    ),
  );
  await api.login('m@fit.test', 'password1');
  return api;
}

void main() {
  test('upload sends the raw image with its type and the token', () async {
    late http.Request seen;
    final api = await signedIn((r) async {
      seen = r;
      return http.Response('', 204);
    });
    expect(
      await api.picture('PUT', bytes: png, contentType: 'image/png'),
      isNull,
    );
    expect(seen.method, 'PUT');
    expect(seen.url.path, '/api/v1/avatar/me');
    expect(seen.headers['Content-Type'], 'image/png');
    expect(seen.headers['Authorization'], 'Bearer a1');
    expect(seen.bodyBytes, png);
  });

  test('picture returns bytes, null when none, error otherwise', () async {
    var status = 200;
    final api = await signedIn(
      (_) async => http.Response.bytes(status == 200 ? png : [], status),
    );
    expect(await api.picture('GET'), png);
    status = 204;
    expect(await api.picture('GET'), isNull);
    status = 400;
    await expectLater(api.picture('GET'), throwsA(isA<ApiError>()));
  });

  Future<List<String>> pick(WidgetTester t, PickedPhoto? photo) async {
    final calls = <String>[];
    final messages = <String>[];
    var stored = false;
    final api = await t.runAsync(
      () => signedIn((r) async {
        calls.add(r.method);
        if (r.method == 'PUT') stored = true;
        if (r.method == 'GET' && stored) return http.Response.bytes(png, 200);
        return http.Response('', 204);
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarEditor(
            api: api!,
            size: 96,
            onMessage: messages.add,
            picker: () async => photo,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('avatar')));
    await t.pumpAndSettle();
    return [...calls, ...messages];
  }

  testWidgets('choosing a photo uploads it and offers removal', (t) async {
    final result = await pick(t, PickedPhoto(png, 'image/png'));
    expect(result, ['GET', 'PUT', 'GET', 'Đã đổi ảnh đại diện.']);
    expect(find.text('Xóa ảnh'), findsOneWidget);
  });

  testWidgets('cancel, wrong type and oversize never upload', (t) async {
    expect(await pick(t, null), ['GET']);
    await t.pumpWidget(const SizedBox());
    expect(await pick(t, PickedPhoto(png, 'image/gif')), [
      'GET',
      'Chỉ nhận ảnh JPG hoặc PNG.',
    ]);
    await t.pumpWidget(const SizedBox());
    expect(
      await pick(t, PickedPhoto(Uint8List(maxAvatarBytes + 1), 'image/png')),
      ['GET', 'Ảnh tối đa 5 MB.'],
    );
  });
}
