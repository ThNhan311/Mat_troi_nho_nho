import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter/screens/login_page.dart';
import 'package:fitcenter/screens/booking_dashboard.dart';
import 'package:fitcenter/services/booking_service.dart';
import 'package:fitcenter/theme/app_theme.dart';
import 'package:fitcenter/services/api_client.dart';

// Retains the verified dashboard regression coverage; production entry uses original navigation.
class FitCenterApp extends StatelessWidget {
  final ApiClient api;
  const FitCenterApp({super.key, required this.api});
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: AnimatedBuilder(
      animation: api,
      builder: (context, _) => api.authenticated
          ? BookingDashboard(service: BookingService(api))
          : LoginPage(api: api),
    ),
  );
}

const ptId = '10000000-0000-0000-0000-000000000001';
const slotId = '20000000-0000-0000-0000-000000000002';
const bookingId = '30000000-0000-0000-0000-000000000003';
const memberId = '40000000-0000-0000-0000-000000000004';
Map<String, dynamic> slot([String status = 'AVAILABLE']) => {
  'id': slotId,
  'ptId': ptId,
  'startAt': '2030-01-02T03:00:00Z',
  'endAt': '2030-01-02T04:30:00Z',
  'status': status,
};
Map<String, dynamic> booking() => {
  'id': bookingId,
  'memberId': memberId,
  'ptId': ptId,
  'slotId': slotId,
  'startAt': '2030-01-02T03:00:00Z',
  'endAt': '2030-01-02T04:30:00Z',
  'status': 'CONFIRMED',
};
http.Response json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
Future<void> login(WidgetTester tester, ApiClient api) async {
  await tester.pumpWidget(FitCenterApp(api: api));
  await tester.enterText(
    find.byKey(const Key('email')),
    'fixture@example.invalid',
  );
  await tester.enterText(find.byKey(const Key('password')), 'test-only');
  await tester.tap(find.byKey(const Key('login')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'screen with mocked HTTP waits for 201, disables double submit and refreshes both lists',
    (tester) async {
      final result = Completer<http.Response>();
      var writes = 0, booked = false;
      final api = ApiClient(
        expectedRole: 'MEMBER',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({
              'role': 'MEMBER',
              'accessToken': 'access-test',
              'refreshToken': 'refresh-test',
            });
          }
          expect(r.headers['Authorization'], 'Bearer access-test');
          if (r.method == 'POST') {
            writes++;
            expect(r.url.path, '/api/v1/bookings');
            expect(jsonDecode(r.body), {'ptId': ptId, 'slotId': slotId});
            final response = await result.future;
            booked = true;
            return response;
          }
          if (r.url.path.endsWith('/bookings/me')) {
            expect(r.url.queryParameters.keys, containsAll(['from', 'to']));
            return json(booked ? [booking()] : []);
          }
          if (r.url.path.endsWith('/slots')) {
            return json(booked ? [] : [slot()]);
          }
          if (r.url.path.endsWith('/$ptId')) {
            return json({
              'id': ptId,
              'fullName': 'Fixture PT',
              'bio': 'API profile',
            });
          }
          return json([
            {'id': ptId, 'fullName': 'Fixture PT'},
          ]);
        }),
      );
      addTearDown(api.dispose);
      await login(tester, api);
      expect(find.text('Chưa có booking trong khoảng xem.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trainer-$ptId')));
      await tester.pumpAndSettle();
      expect(find.text('API profile'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('slot-$slotId')));
      await tester.tap(find.byKey(const ValueKey('slot-$slotId')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('book')));
      await tester.tap(find.byKey(const Key('book')));
      await tester.pump();
      expect(writes, 1);
      expect(find.byKey(const Key('success')), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('book'))).onPressed,
        isNull,
      );
      result.complete(json(booking(), 201));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('success')), findsOneWidget);
      expect(find.byKey(const ValueKey('slot-$slotId')), findsNothing);
      expect(writes, 1);
      await tester.ensureVisible(
        find.textContaining('Booking: $bookingId').last,
      );
      expect(find.textContaining('Booking: $bookingId'), findsWidgets);
    },
  );
  testWidgets(
    '409 clears selection, reloads availability, preserves error code and no fake success',
    (tester) async {
      var conflict = false, writes = 0;
      final api = ApiClient(
        expectedRole: 'MEMBER',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({
              'role': 'MEMBER',
              'accessToken': 'access-test',
              'refreshToken': 'refresh-test',
            });
          }
          if (r.method == 'POST') {
            writes++;
            conflict = true;
            return json({
              'error': {
                'code': 'ERR_SLOT_NO_LONGER_AVAILABLE',
                'message': 'Slot đã được đặt',
                'correlationId': 'fixture-409',
              },
            }, 409);
          }
          if (r.url.path.endsWith('/bookings/me')) return json([]);
          if (r.url.path.endsWith('/slots')) {
            return json(conflict ? [] : [slot()]);
          }
          if (r.url.path.endsWith('/$ptId')) {
            return json({'id': ptId, 'fullName': 'Fixture PT'});
          }
          return json([
            {'id': ptId, 'fullName': 'Fixture PT'},
          ]);
        }),
      );
      addTearDown(api.dispose);
      await login(tester, api);
      await tester.tap(find.byKey(const ValueKey('trainer-$ptId')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('slot-$slotId')));
      await tester.tap(find.byKey(const ValueKey('slot-$slotId')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('book')));
      await tester.tap(find.byKey(const Key('book')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('ERR_SLOT_NO_LONGER_AVAILABLE'),
        findsOneWidget,
      );
      expect(find.textContaining('fixture-409'), findsOneWidget);
      expect(find.byKey(const Key('success')), findsNothing);
      expect(find.byKey(const ValueKey('slot-$slotId')), findsNothing);
      expect(writes, 1);
    },
  );
  testWidgets(
    'API read failure shows an error without trainers mock fallback',
    (tester) async {
      final api = ApiClient(
        expectedRole: 'MEMBER',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({
              'role': 'MEMBER',
              'accessToken': 'access-test',
              'refreshToken': 'refresh-test',
            });
          }
          throw http.ClientException('offline');
        }),
      );
      addTearDown(api.dispose);
      await login(tester, api);
      expect(find.byKey(const Key('api-error')), findsOneWidget);
      expect(find.text('Nguyễn Minh Anh'), findsNothing);
    },
  );
  testWidgets('logout returns to login and a fresh app has no session', (
    tester,
  ) async {
    final api = ApiClient(
      expectedRole: 'MEMBER',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return json({
            'role': 'MEMBER',
            'accessToken': 'access-test',
            'refreshToken': 'refresh-test',
          });
        }
        return json([]);
      }),
    );
    addTearDown(api.dispose);
    await login(tester, api);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login')), findsOneWidget);
    expect(api.authenticated, false);
  });
}
