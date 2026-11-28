import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcenter/screens/transfer_dialog.dart';
import 'package:fitcenter/screens/transfer_info.dart';
import 'package:fitcenter/services/renewal_models.dart';
import 'package:fitcenter/services/renewal_service.dart';

import 'renewal_test.dart';

void main() {
  testWidgets('shows QR and details until the server confirms', (tester) async {
    var reads = 0;
    final client = api((request) async {
      reads++;
      return response(
        reads == 1
            ? quote()
            : quote(status: 'SUCCESS', fulfillment: 'APPLIED'),
      );
    });
    await client.login('member@example.test', 'unit-password');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: TransferDialog(
          service: RenewalService(client),
          payment: RenewalPayment.parse(quote()),
        ),
      ),
    );
    expect(find.byKey(const Key('transfer-qr')), findsOneWidget);
    expect(find.text(transferCode(paymentId)), findsOneWidget);
    expect(find.text(transferAccount), findsOneWidget);
    expect(find.textContaining('mô phỏng'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byKey(const Key('transfer-done')), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byKey(const Key('transfer-done')), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    expect(reads, 2);
  });
}