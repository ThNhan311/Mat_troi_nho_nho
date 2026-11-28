import 'package:flutter/material.dart';

import '../services/initial_activation_service.dart';
import 'transfer_info.dart';
import '../widgets/selectable_dialog.dart';

/// How the money for a first package reaches the front desk.
class PaymentMethodField extends StatelessWidget {
  final bool transfer;
  final ValueChanged<bool>? onChanged;
  const PaymentMethodField({
    super.key,
    required this.transfer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Tiền mặt'),
          icon: Icon(Icons.payments_outlined),
        ),
        ButtonSegment(
          value: true,
          label: Text('Chuyển khoản'),
          icon: Icon(Icons.qr_code_2),
        ),
      ],
      selected: {transfer},
      onSelectionChanged: onChanged == null
          ? null
          : (value) => onChanged!(value.first),
    ),
  );
}

/// Shows the QR to the customer. Returns the receipt reference once the staff
/// member confirms the money arrived, or null if closed first.
Future<String?> collectByTransfer(BuildContext context, String amount) {
  final code = transferCode(newActivationKey());
  return showSelectableDialog<String>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: false,
    builder: (dialog) => AlertDialog(
      title: const Text('Thanh toán chuyển khoản'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: TransferInfo(amount: amount, code: code),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('transfer-cancel'),
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          key: const Key('transfer-received'),
          onPressed: () => Navigator.pop(dialog, 'CK-$code'),
          child: const Text('Đã nhận được tiền'),
        ),
      ],
    ),
  );
}
