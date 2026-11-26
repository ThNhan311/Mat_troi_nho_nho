import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/screens/report_pages.dart';
import 'package:fitcenter_ad/services/api_client.dart';
import 'package:fitcenter_ad/services/report_service.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<List<Uri>> open(
  WidgetTester t,
  Widget Function(ReportService) page,
  http.Response Function(String path) answer,
) async {
  await t.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => t.binding.setSurfaceSize(null));
  final reads = <Uri>[];
  final api = ApiClient(
    expectedRole: 'ADMIN',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: MockClient((r) async {
      if (r.url.path.endsWith('/login')) {
        return json({'role': 'ADMIN', 'accessToken': 'a', 'refreshToken': 'r'});
      }
      expect(r.method, 'GET');
      reads.add(r.url);
      return answer(r.url.path);
    }),
  );
  addTearDown(api.dispose);
  await api.login('admin@example.invalid', 'synthetic');
  await t.pumpWidget(MaterialApp(home: page(ReportService(api))));
  await t.pumpAndSettle();
  return reads;
}

void main() {
  test('today is the Vietnam day, not the UTC day', () {
    expect(
      vietnamToday(DateTime.utc(2030, 1, 1, 18)),
      DateTime.utc(2030, 1, 2),
    );
  });

  testWidgets('schedule shows Vietnam time, filters and asks by range', (
    t,
  ) async {
    final reads = await open(
      t,
      (s) => SchedulePage(service: s),
      (_) => json([
        {
          'startAt': '2030-01-01T01:00:00Z',
          'endAt': '2030-01-01T02:30:00Z',
          'trainerName': 'PT Binh',
          'memberName': 'An',
          'status': 'CONFIRMED',
        },
        {
          'startAt': '2030-01-01T03:00:00Z',
          'endAt': '2030-01-01T04:30:00Z',
          'trainerName': 'PT Chi',
          'memberName': null,
          'status': 'OPEN',
        },
      ]),
    );
    expect(find.text('08:00 – 09:30'), findsOneWidget);
    expect(find.text('2 dòng'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'binh');
    await t.pumpAndSettle();
    expect(find.text('1 dòng'), findsOneWidget);
    expect(find.text('PT Chi'), findsNothing);
    await t.tap(find.widgetWithText(ChoiceChip, 'Hôm nay'));
    await t.pumpAndSettle();
    expect(reads.length, 2);
    expect(
      reads.last.queryParameters['from'],
      reads.last.queryParameters['to'],
    );
  });

  testWidgets('a server error is not shown as an empty history', (t) async {
    await open(
      t,
      (s) => SchedulePage(service: s),
      (_) => json({
        'error': {'code': 'ERR_INTERNAL', 'message': 'Broken'},
      }, 500),
    );
    expect(find.textContaining('Broken'), findsOneWidget);
    expect(find.textContaining('Không có buổi tập'), findsNothing);
  });
}
