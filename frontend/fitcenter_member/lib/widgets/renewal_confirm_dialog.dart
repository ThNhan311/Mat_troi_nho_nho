import 'package:flutter/material.dart';

import '../services/renewal_models.dart';

/// Last check before a renewal payment is created. Pops true to go ahead.
class RenewalConfirmDialog extends StatelessWidget {
  const RenewalConfirmDialog({
    super.key,
    required this.planName,
    required this.days,
    required this.cents,
  });

  final String planName;
  final int days;
  final int cents;

  /// Label on the left, value flush right like the amount below.
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: const Text(
        'Xác nhận gia hạn',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  _row('Gói tập', planName),
                  _row('Thời hạn', '$days ngày'),
                  _row('Hình thức thanh toán', 'Chuyển khoản'),
                  const Divider(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Text('Số tiền'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            paymentMoney(cents),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thời hạn được cộng sau khi phòng tập xác nhận thanh toán. '
                    'Giá và thời lượng được chốt khi tạo.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      // Actions stay visible even when a short screen makes the rest scroll.
      actions: [
        SizedBox(
          width: 340,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Quay lại'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Xác nhận'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
