import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcenter_ad/screens/plan_form.dart';
import 'package:fitcenter_ad/screens/transfer_info.dart';
import 'package:fitcenter_ad/services/admin_account_service.dart';

import 'renewal_test.dart';

const _plan = '10000000-0000-4000-8000-000000000004';

void main() {
  testWidgets('transfer shows the QR and activates only after confirming', (
    tester,
  ) async {
    final bodies = <Map<String, dynamic>>[];
    final client = api((request) async {
      if (request.method == 'POST') {
        bodies.add(jsonDecode(request.body));
        return response({
          'error': {'code': 'ERR_CONFLICT', 'message': 'Conflict'},
        }, 409);
      }
      return response([
        {
          'id': _plan,
          'name': 'Month',
          'description': null,
          'durationDays': 30,
          'price': 100000,
        },
      ]);
    });
    await client.login('unit@example.invalid', 'unit-only');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanDialog(
            api: client,
            account: AdminAccount.parse({
              'userId': '10000000-0000-4000-8000-000000000007',
              'profileId': '10000000-0000-4000-8000-000000000003',
              'email': 'member@example.test',
              'fullName': 'Unit member',
              'role': 'MEMBER',
              'status': 'ACTIVE',
              'activationPending': false,
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Month').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển khoản'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-receipt')), findsNothing);

    await tester.tap(find.byKey(const Key('plan-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transfer-qr')), findsOneWidget);
    expect(find.text(transferAccount), findsOneWidget);
    expect(find.textContaining('mô phỏng'), findsNothing);
    await tester.tap(find.byKey(const Key('transfer-cancel')));
    await tester.pumpAndSettle();
    expect(bodies, isEmpty);

    await tester.tap(find.byKey(const Key('plan-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer-received')));
    await tester.pumpAndSettle();
    expect(bodies.single['receiptRef'], matches(r'^CK-FC[0-9A-F]{10}$'));
    expect(bodies.single['amountCollected'], 100000);
  });
}