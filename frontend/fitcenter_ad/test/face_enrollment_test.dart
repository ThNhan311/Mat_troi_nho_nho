import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/main.dart';
import 'package:fitcenter_ad/screens/face_enrollment_page.dart';
import 'package:fitcenter_ad/services/api_client.dart';
import 'package:fitcenter_ad/services/face_enrollment_service.dart';

const member = '10000000-0000-4000-8000-000000000001',
    user = '10000000-0000-4000-8000-000000000002',
    op = '10000000-0000-4000-8000-000000000003',
    profile = '10000000-0000-4000-8000-000000000004',
    key = '10000000-0000-4000-8000-000000000005';
Map<String, dynamic> row([String status = 'PENDING']) => {
  'id': op,
  'requestId': key,
  'memberId': member,
  'status': status,
  'proposedProfileId': profile,
  'profileId': status == 'ACTIVE' || status == 'REVOKED' ? profile : null,
  'verificationMode': 'SIMULATED_TEST',
  'consentVersion': 'face-consent-v1',
  'startedAt': '2026-11-24T03:00:00Z',
  'cleanupPending': false,
  'failureCode': status == 'FAILED' ? 'ERR_FACE_SAMPLE_NOT_READY' : null,
};
Map<String, dynamic> state({
  List<dynamic> ops = const [],
  List<dynamic> profiles = const [],
}) => {'memberId': member, 'enrollments': ops, 'profiles': profiles};
Map<String, dynamic> face(String status) => {
  'id': profile,
  'status': status,
  'verificationMode': 'SIMULATED_TEST',
  'enrolledAt': '2026-11-24T03:00:00Z',
  'revokedAt': status == 'REVOKED' ? '2026-11-24T04:00:00Z' : null,
};
http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiClient api(
  Future<http.Response> Function(http.Request) handler, {
  Duration? timeout,
}) => ApiClient(
  expectedRole: 'ADMIN',
  baseUri: Uri.parse('http://localhost/api/v1'),
  timeout: timeout ?? const Duration(seconds: 15),
  client: MockClient((r) async {
    if (r.url.path.endsWith('/login'))
      return json({
        'role': 'ADMIN',
        'accessToken': 'test-only-access',
        'refreshToken': 'test-only-refresh',
      });
    if (r.url.path.endsWith('/admin/members'))
      return json([
        {
          'userId': user,
          'profileId': member,
          'email': 'fixture@example.invalid',
          'fullName': 'Fixture Member',
          'role': 'MEMBER',
          'status': 'ACTIVE',
          'activationPending': false,
        },
      ]);
    return handler(r);
  }),
);
Future<ApiClient> ready(
  Future<http.Response> Function(http.Request) handler, {
  Duration? timeout,
}) async {
  final a = api(handler, timeout: timeout);
  await a.login('fixture@example.invalid', 'test-only');
  return a;
}

void main() {
  test(
    'start sends consent and idempotency, never identity attestation',
    () async {
      final a = await ready((r) async {
        expect(r.method, 'POST');
        expect(r.headers['idempotency-key'], key);
        final b = jsonDecode(r.body) as Map;
        expect(b.keys.toSet(), {
          'consentAccepted',
          'memberVerified',
          'atGym',
          'consentVersion',
        });
        expect(b['consentAccepted'], true);
        return json(row(), 201);
      });
      final result = await FaceEnrollmentService(a)
          .start(member, key, consent: true, verified: true, atGym: true);
      expect(result.status, 'PENDING');
      a.dispose();
    },
  );
  for (final status in ['PENDING', 'ACTIVE', 'FAILED', 'REVOKED']) {
    test('maps lifecycle $status without inventing success', () async {
      final a = await ready(
        (r) async => json(
          state(
            ops: [row(status)],
            profiles: status == 'ACTIVE' || status == 'REVOKED'
                ? [face(status)]
                : [],
          ),
        ),
      );
      final s = await FaceEnrollmentService(a).read(member);
      expect(s.enrollments.single.status, status);
      expect(s.enrollments.single.mode, 'SIMULATED_TEST');
      a.dispose();
    });
  }
  test('complete posts only operation and uses server state', () async {
    final a = await ready((r) async {
      expect(r.url.path.endsWith('/$op/complete'), true);
      expect(jsonDecode(r.body), {});
      return json(row('FAILED'));
    });
    expect(
      (await FaceEnrollmentService(a).complete(member, op)).status,
      'FAILED',
    );
    a.dispose();
  });
  test('revoke requires server REVOKED and accepts cleanup pending', () async {
    final a = await ready((r) async {
      expect(r.headers['idempotency-key'], key);
      return json(
        state(
          ops: [
            {...row('REVOKED'), 'cleanupPending': true},
          ],
          profiles: [face('REVOKED')],
        ),
      );
    });
    final s = await FaceEnrollmentService(a).revoke(member, profile, key);
    expect(s.enrollments.single.cleanupPending, true);
    a.dispose();
  });
  for (final bad in [
    null,
    {},
    {...row('ACTIVE'), 'profileId': user},
    {...row(), 'memberId': 'bad'},
    {...row(), 'verificationMode': 'REAL_FACE'},
    {...row(), 'startedAt': '2026-11-24T03:00:00+07:00'},
  ]) {
    test('rejects malformed or unproven response ${bad.hashCode}', () {
      expect(
        () => FaceEnrollment.parse(bad, write: true),
        throwsA(
          isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true),
        ),
      );
    });
  }
  test('does not accept wrong member or multiple active profiles', () {
    expect(
      () => FaceEnrollmentState.parse({...state(), 'memberId': user}, member),
      throwsA(isA<ApiError>()),
    );
    expect(
      () => FaceEnrollmentState.parse(
        state(
          profiles: [
            face('ACTIVE'),
            {...face('ACTIVE'), 'id': op},
          ],
        ),
        member,
      ),
      throwsA(isA<ApiError>()),
    );
  });
  test(
    'PUT-like false success is rejected when revoke returns ACTIVE',
    () async {
      final a = await ready(
        (r) async => json(state(profiles: [face('ACTIVE')])),
      );
      await expectLater(
        FaceEnrollmentService(a).revoke(member, profile, key),
        throwsA(
          isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true),
        ),
      );
      a.dispose();
    },
  );
  test('409 retains envelope and no automatic POST replay', () async {
    var writes = 0;
    final a = await ready((r) async {
      writes++;
      return json({
        'error': {
          'code': 'ERR_FACE_ENROLLMENT_PENDING',
          'message': 'Reconcile',
          'correlationId': 'fixture-correlation',
        },
      }, 409);
    });
    await expectLater(
      FaceEnrollmentService(a)
          .start(member, key, consent: true, verified: true, atGym: true),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', 'ERR_FACE_ENROLLMENT_PENDING')
            .having(
              (e) => e.correlationId,
              'correlation',
              'fixture-correlation',
            ),
      ),
    );
    expect(writes, 1);
    a.dispose();
  });
  test('timeout has unknown outcome and one write only', () async {
    var writes = 0;
    final blocked = Completer<http.Response>();
    final a = await ready((r) {
      writes++;
      return blocked.future;
    }, timeout: const Duration(milliseconds: 10));
    await expectLater(
      FaceEnrollmentService(a).complete(member, op),
      throwsA(isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true)),
    );
    expect(writes, 1);
    blocked.complete(json(row('ACTIVE')));
    a.dispose();
  });
  test('response after logout is rejected', () async {
    final blocked = Completer<http.Response>();
    final a = await ready((r) => blocked.future);
    final pending = FaceEnrollmentService(a).read(member);
    a.logout();
    blocked.complete(json(state()));
    await expectLater(
      pending,
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')),
    );
    a.dispose();
  });
  testWidgets('original navigation offers enrollment and empty/error states', (
    t,
  ) async {
    final a = await ready((r) async => json(state()));
    await t.pumpWidget(FitCenterAdminApp(api: a));
    await t.pumpAndSettle();
    final menu = find.text('Đăng ký khuôn mặt');
    await t.ensureVisible(menu);
    await t.tap(menu);
    await t.pumpAndSettle();
    expect(find.byType(FaceEnrollmentPage), findsOneWidget);
    await t.tap(find.byKey(const Key('face-member')));
    await t.pumpAndSettle();
    await t.tap(find.text('Fixture Member • 10000000').last);
    await t.pumpAndSettle();
    expect(find.text('Chưa có hồ sơ khuôn mặt.'), findsOneWidget);
    final start = find.widgetWithText(FilledButton, 'Bắt đầu đăng ký');
    expect(t.widget<FilledButton>(start).onPressed, isNull);
    await t.pumpWidget(const SizedBox());
    a.dispose();
  });
  testWidgets('pending and failed are shown, not active success', (t) async {
    final a = await ready(
      (r) async => json(
        state(
          ops: [
            row(),
            {...row('FAILED'), 'id': user},
          ],
        ),
      ),
    );
    await t.pumpWidget(FitCenterAdminApp(api: a));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Đăng ký khuôn mặt'));
    await t.tap(find.text('Đăng ký khuôn mặt'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('face-member')));
    await t.pumpAndSettle();
    await t.tap(find.text('Fixture Member • 10000000').last);
    await t.pumpAndSettle();
    expect(find.textContaining('Đang chờ mẫu'), findsOneWidget);
    await t.scrollUntilVisible(find.textContaining('Đăng ký thất bại'), 200);
    await t.pumpAndSettle();
    expect(find.textContaining('Đăng ký thất bại'), findsOneWidget);
    expect(find.textContaining('Đang hoạt động'), findsNothing);
    await t.pumpWidget(const SizedBox());
    a.dispose();
  });
  testWidgets('logout dismisses enrollment route and late result', (t) async {
    final blocked = Completer<http.Response>();
    final a = await ready((r) => blocked.future);
    await t.pumpWidget(FitCenterAdminApp(api: a));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Đăng ký khuôn mặt'));
    await t.tap(find.text('Đăng ký khuôn mặt'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('face-member')));
    await t.pumpAndSettle();
    await t.tap(find.text('Fixture Member • 10000000').last);
    await t.pump();
    a.logout();
    await t.pump();
    blocked.complete(json(state(ops: [row('ACTIVE')])));
    await t.pumpAndSettle();
    expect(find.byType(FaceEnrollmentPage), findsNothing);
    expect(find.textContaining('Đang hoạt động'), findsNothing);
    await t.pumpWidget(const SizedBox());
    a.dispose();
  });
  test(
    'pending revoke uses existing operation, no client template fields',
    () async {
      final a = await ready((r) async {
        expect(r.url.path.endsWith('/$op/revoke'), true);
        expect(jsonDecode(r.body), {});
        return json(row('REVOKED'));
      });
      expect(
        (await FaceEnrollmentService(a).revokePending(member, op)).status,
        'REVOKED',
      );
      a.dispose();
    },
  );
  testWidgets(
    'consent start and complete follow server states, double tap sends once',
    (t) async {
      String? status, sentKey;
      var writes = 0;
      final blocked = Completer<http.Response>();
      final a = await ready((r) async {
        if (r.method == 'POST') {
          writes++;
          if (r.url.path.endsWith('/complete')) {
            status = 'ACTIVE';
            return json({...row(status!), 'requestId': sentKey});
          }
          status = 'PENDING';
          sentKey = r.headers['idempotency-key'];
          return blocked.future;
        }
        return json(
          state(
            ops: status == null
                ? []
                : [
                    {...row(status!), 'requestId': sentKey},
                  ],
            profiles: status == 'ACTIVE' ? [face('ACTIVE')] : [],
          ),
        );
      });
      await t.pumpWidget(FitCenterAdminApp(api: a));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Đăng ký khuôn mặt'));
      await t.tap(find.text('Đăng ký khuôn mặt'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('face-member')));
      await t.pumpAndSettle();
      await t.tap(find.text('Fixture Member • 10000000').last);
      await t.pumpAndSettle();
      for (final name in ['face-verified', 'face-gym', 'face-consent']) {
        await t.ensureVisible(find.byKey(Key(name)));
        await t.tap(find.byKey(Key(name)));
        await t.pumpAndSettle();
      }
      final button = find.widgetWithText(FilledButton, 'Bắt đầu đăng ký');
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pump();
      await t.tap(button, warnIfMissed: false);
      await t.pump();
      expect(writes, 1);
      expect(find.textContaining('Đang hoạt động'), findsNothing);
      blocked.complete(json({...row(), 'requestId': sentKey}, 201));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Kiểm tra mẫu và hoàn tất'), 200);
      await t.tap(find.text('Kiểm tra mẫu và hoàn tất'));
      await t.pumpAndSettle();
      expect(writes, 2);
      await t.scrollUntilVisible(
        find.textContaining('Đang hoạt động').first,
        -200,
      );
      expect(find.textContaining('Đang hoạt động'), findsWidgets);
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );
}
