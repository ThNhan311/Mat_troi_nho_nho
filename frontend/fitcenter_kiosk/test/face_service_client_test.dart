import 'dart:convert';
import 'dart:typed_data';

import 'package:fitcenter_kiosk/features/kiosk/services/face_service_client.dart';
import 'package:fitcenter_kiosk/features/kiosk/services/kiosk_checkin_service.dart';
import 'package:fitcenter_kiosk/features/kiosk/services/kiosk_enrollment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final List<Uint8List> frames = [
  Uint8List.fromList([1, 2, 3]),
  Uint8List.fromList([4, 5, 6]),
];

http.Response json(Map<String, Object?> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

FaceServiceClient clientFor(
  Future<http.Response> Function(http.Request) handler, {
  Duration? timeout,
}) => FaceServiceClient(
  httpClient: MockClient(handler),
  baseUrl: 'http://face.test',
  kioskToken: 'kiosk-secret',
  timeout: timeout,
);

Future<FaceServiceException> failureOf(Future<Object?> call) async {
  try {
    await call;
  } on FaceServiceException catch (error) {
    return error;
  }
  fail('Expected FaceServiceException');
}

void main() {
  group('identify', () {
    test('success sends token and every frame, returns member id', () async {
      late http.Request seen;
      final client = clientFor((request) async {
        seen = request;
        return json({
          'request_id': 'r1',
          'outcome': 'SUCCESS',
          'member_id': 'M001',
          'score': 0.8,
          'liveness': 'NOT_PERFORMED',
        });
      });

      final result = await client.identify(frames);

      expect(result.outcome, FaceOutcome.success);
      expect(result.memberId, 'M001');
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'http://face.test/v1/identify');
      expect(seen.headers['X-Kiosk-Token'], 'kiosk-secret');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      expect('name="frames"'.allMatches(seen.body).length, 2);
    });

    test('maps REJECTED and NO_FACE', () async {
      for (final entry in {
        'REJECTED': FaceOutcome.rejected,
        'NO_FACE': FaceOutcome.noFace,
      }.entries) {
        final client = clientFor(
          (_) async => json({'outcome': entry.key, 'member_id': null}),
        );
        final result = await client.identify(frames);
        expect(result.outcome, entry.value);
        expect(result.memberId, isNull);
      }
    });

    test('error response keeps the API error code', () async {
      final client = clientFor(
        (_) async => json({'error': 'BUSY', 'detail': 'retry'}, 503),
      );

      final error = await failureOf(client.identify(frames));

      expect(error.code, 'BUSY');
      expect(error.statusCode, 503);
    });

    test('unauthorized is reported, not treated as no match', () async {
      final client = clientFor(
        (_) async => json({'error': 'UNAUTHORIZED', 'detail': 'x'}, 401),
      );

      expect((await failureOf(client.identify(frames))).code, 'UNAUTHORIZED');
    });

    test('malformed responses become BAD_RESPONSE', () async {
      final bodies = <http.Response>[
        http.Response('not json', 200),
        http.Response('[]', 200),
        json({'outcome': 'SUCCESS'}),
        json({'outcome': 'SUCCESS', 'member_id': ''}),
        json({'outcome': 'SOMETHING_ELSE'}),
        http.Response('<html>', 502),
      ];
      for (final response in bodies) {
        final client = clientFor((_) async => response);
        expect((await failureOf(client.identify(frames))).code, 'BAD_RESPONSE');
      }
    });

    test('connection failure becomes NETWORK', () async {
      final client = clientFor((_) async => throw http.ClientException('down'));

      expect((await failureOf(client.identify(frames))).code, 'NETWORK');
    });

    test('slow service becomes TIMEOUT', () async {
      final client = clientFor((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return json({'outcome': 'REJECTED'});
      }, timeout: const Duration(milliseconds: 50));

      expect((await failureOf(client.identify(frames))).code, 'TIMEOUT');
    });
  });

  group('enroll', () {
    test('sends admin token and member id', () async {
      late http.Request seen;
      final client = clientFor((request) async {
        seen = request;
        return json({'member_id': 'M002', 'samples_used': 2, 'members': 5});
      });

      final result = await client.enroll(
        memberId: 'M002',
        adminToken: 'admin-secret',
        frames: frames,
      );

      expect(result.memberId, 'M002');
      expect(result.samplesUsed, 2);
      expect(seen.url.path, '/v1/enroll');
      expect(seen.headers['X-Admin-Token'], 'admin-secret');
      expect(seen.headers.containsKey('X-Kiosk-Token'), isFalse);
      expect(seen.body, contains('name="member_id"'));
      expect(seen.body, contains('M002'));
    });
  });

  group('services', () {
    test('check-in: only SUCCESS is a success', () async {
      final ok = KioskCheckinService(
        client: clientFor(
          (_) async => json({'outcome': 'SUCCESS', 'member_id': 'M001'}),
        ),
      );
      final response = await ok.checkIn(frames);
      expect(response.result, CheckInResult.success);
      expect(response.memberName, 'M001');

      for (final outcome in ['REJECTED', 'NO_FACE']) {
        final service = KioskCheckinService(
          client: clientFor((_) async => json({'outcome': outcome})),
        );
        expect((await service.checkIn(frames)).result, CheckInResult.noMatch);
      }
    });

    test('face presence: only NO_FACE means nobody is there', () async {
      for (final entry in {
        'NO_FACE': false,
        'REJECTED': true,
        'SUCCESS': true,
      }.entries) {
        final service = KioskCheckinService(
          client: clientFor(
            (_) async => json({
              'outcome': entry.key,
              'member_id': entry.key == 'SUCCESS' ? 'M001' : null,
            }),
          ),
        );
        expect(
          await service.isFacePresent(frames),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('face presence: service errors propagate to the caller', () async {
      final service = KioskCheckinService(
        client: clientFor((_) async => json({'error': 'BUSY'}, 503)),
      );

      expect((await failureOf(service.isFacePresent(frames))).code, 'BUSY');
    });

    test('check-in: service errors propagate to the caller', () async {
      final service = KioskCheckinService(
        client: clientFor((_) async => json({'error': 'BUSY'}, 503)),
      );

      expect((await failureOf(service.checkIn(frames))).code, 'BUSY');
    });

    test('enrollment: errors become failed, success stays success', () async {
      final failing = KioskEnrollmentService(
        client: clientFor(
          (_) async => json({'error': 'DUPLICATE_IDENTITY'}, 409),
        ),
      );
      expect(
        await failing.enroll(memberId: 'M1', adminToken: 't', frames: frames),
        EnrollmentResult.duplicate,
      );

      final unauthorized = KioskEnrollmentService(
        client: clientFor((_) async => json({'error': 'UNAUTHORIZED'}, 401)),
      );
      expect(
        await unauthorized.enroll(
          memberId: 'M1',
          adminToken: 't',
          frames: frames,
        ),
        EnrollmentResult.failed,
      );

      final working = KioskEnrollmentService(
        client: clientFor(
          (_) async => json({'member_id': 'M1', 'samples_used': 2}),
        ),
      );
      expect(
        await working.enroll(memberId: 'M1', adminToken: 't', frames: frames),
        EnrollmentResult.success,
      );
    });
  });
}
