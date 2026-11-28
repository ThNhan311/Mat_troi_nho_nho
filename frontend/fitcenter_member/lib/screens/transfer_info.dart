import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/renewal_models.dart';

// Demo payee. The bank is made up and the QR holds plain text, not a bank
// transfer code, so nothing here can send money to anyone.
const transferBank = 'FitBank';
const transferAccount = '0000 1234 5678';
const transferHolder = 'PHONG TAP FITCENTER';

/// Transfer content that identifies one payment.
String transferCode(String id) =>
    'FC${id.replaceAll('-', '').substring(0, 10).toUpperCase()}';

class TransferInfo extends StatelessWidget {
  final String amount, code;
  const TransferInfo({super.key, required this.amount, required this.code});

  Widget row(String label, String value, {bool copy = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(width: 104, child: Text(label)),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (copy)
          IconButton(
            tooltip: 'Sao chép $label',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Container(
          key: const Key('transfer-qr'),
          width: 200,
          height: 200,
          // A white quiet zone keeps the code visible in dark mode.
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: QrImageView(
            padding: EdgeInsets.zero,
            semanticsLabel: 'Mã QR chuyển khoản',
            data: 'FITCENTER|$transferAccount|$amount|$code',
          ),
        ),
      ),
      const SizedBox(height: 12),
      row('Ngân hàng', transferBank),
      row('Số tài khoản', transferAccount, copy: true),
      row('Chủ tài khoản', transferHolder),
      row('Số tiền', paymentMoney(exactPaymentCents(amount))),
      row('Nội dung', code, copy: true),
    ],
  );
}
