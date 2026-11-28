import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_kiosk/features/kiosk/services/core_client.dart';
import 'package:fitcenter_kiosk/features/kiosk/services/face_service_client.dart';
import 'package:fitcenter_kiosk/features/kiosk/services/kiosk_checkin_service.dart';

const member = '20000000-0000-0000-0000-000000000001';

CoreClient core(MockClientHandler handler) => CoreClient(
  httpClient: MockClient(handler),
  baseUrl: 'http://127.0.0.1/api/v1',
  token: 'test-token',
);

KioskCheckinService service(MockClientHandler backend) => KioskCheckinService(
  client: FaceServiceClient(
    httpClient: MockClient(
      (_) async => http.Response(
        jsonEncode({'outcome': 'SUCCESS', 'member_id': member}),
        200,
      ),
    ),
    baseUrl: 'http://127.0.0.1:8750',
    kioskToken: 'face-token',
  ),
  core: core(backend),
);

http.Response card(bool valid) => http.Response.bytes(
  utf8.encode(jsonEncode({'fullName': 'Lê An', 'membershipValid': valid})),
  200,
);

void main() {
  final frames = [
    Uint8List.fromList([1]),
  ];

  test('no waiting request is not an error, token is sent', () async {
    final client = core((r) async {
      expect(r.headers['X-Kiosk-Token'], 'test-token');
      return http.Response('', 204);
    });
    expect(await client.pending(), isNull);
  });

  test('recognised member shows the name from the server', () async {
    final result = await service((r) async {
      expect(r.url.path, '/api/v1/kiosk/members/$member/scan');
      return card(true);
    }).checkIn(frames);
    expect(result.result, CheckInResult.success);
    expect(result.memberName, 'Lê An');
  });

  test('no valid membership is reported as such', () async {
    final result = await service((_) async => card(false)).checkIn(frames);
    expect(result.result, CheckInResult.membershipInvalid);
  });

  test('face without a member account does not check in', () async {
    final result = await service((_) async => http.Response('{}', 404))
        .checkIn(frames);
    expect(result.result, CheckInResult.noMatch);
  });

  test('server failure never becomes a successful check-in', () async {
    await expectLater(
      service((_) async => http.Response('{}', 500)).checkIn(frames),
      throwsA(isA<CoreException>()),
    );
  });
}
