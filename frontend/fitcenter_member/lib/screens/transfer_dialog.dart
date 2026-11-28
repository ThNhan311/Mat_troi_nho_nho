import 'dart:async';

import 'package:flutter/material.dart';

import '../services/renewal_models.dart';
import '../services/renewal_service.dart';
import 'transfer_info.dart';

/// Payment details for one pending renewal. While open it re-reads the payment;
/// only the server's status says whether it has been confirmed.
class TransferDialog extends StatefulWidget {
  final RenewalService service;
  final RenewalPayment payment;
  const TransferDialog({
    super.key,
    required this.service,
    required this.payment,
  });

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  late final int epoch = widget.service.api.sessionEpoch;
  late RenewalPayment payment = widget.payment;
  Timer? timer;
  bool reading = false;

  bool get current =>
      mounted &&
      widget.service.api.authenticated &&
      widget.service.api.sessionEpoch == epoch;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (!current || reading || payment.status != 'PENDING') return;
    reading = true;
    try {
      final value = await widget.service.payment(payment.id);
      if (!current) return;
      if (value.status != 'PENDING') {
        timer?.cancel();
        setState(() => payment = value);
      }
    } catch (_) {
      // A failed read changes nothing; the next one tries again.
    } finally {
      reading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = payment.status == 'PENDING';
    return AlertDialog(
      title: const Text('Thanh toán chuyển khoản'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: waiting
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TransferInfo(
                      amount: paymentDecimal(payment.cents),
                      code: transferCode(payment.id),
                    ),
                    const SizedBox(height: 8),
                    const Text('Đang chờ phòng tập xác nhận…'),
                  ],
                )
              : Text(
                  payment.start != null && payment.end != null
                      ? 'Thanh toán thành công. Gói được gia hạn từ ${showPaidDate(payment.start!)} đến ${showPaidDate(payment.end!)}.'
                      : '${payment.statusLabel}. ${payment.fulfillmentLabel}.',
                  key: const Key('transfer-done'),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
