import 'package:flutter/material.dart';

class RenewalPaymentPage extends StatefulWidget {
  final String? planTitle;
  final String? planPrice;
  final ValueChanged<Map<String, dynamic>>? onPaymentSuccess;

  const RenewalPaymentPage({
    super.key,
    this.planTitle,
    this.planPrice,
    this.onPaymentSuccess,
  });

  @override
  State<RenewalPaymentPage> createState() =>
      _RenewalPaymentPageState();
}

class _RenewalPaymentPageState extends State<RenewalPaymentPage> {
  late int selectedPlan;

  String selectedPaymentMethod = 'Thanh toán mô phỏng';

  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Gói 1 tháng',
      'duration': '30 ngày',
      'price': 500000,
      'description': 'Phù hợp để trải nghiệm FitCenter.',
    },
    {
      'name': 'Gói 3 tháng',
      'duration': '90 ngày',
      'price': 1500000,
      'description': 'Tiết kiệm hơn so với đăng ký từng tháng.',
    },
    {
      'name': 'Gói 6 tháng',
      'duration': '180 ngày',
      'price': 2700000,
      'description': 'Tiết kiệm cho kế hoạch dài hạn.',
    },
  ];

  final List<Map<String, dynamic>> paymentMethods = [
    {
      'name': 'Thanh toán mô phỏng',
      'subtitle': 'Dùng cho bản demo frontend',
      'icon': Icons.credit_card,
    },
    {
      'name': 'Ví điện tử',
      'subtitle': 'Sẵn sàng tích hợp payment gateway',
      'icon': Icons.account_balance_wallet_outlined,
    },
    {
      'name': 'Chuyển khoản',
      'subtitle': 'Thanh toán qua tài khoản ngân hàng',
      'icon': Icons.account_balance,
    },
  ];

  @override
  void initState() {
    super.initState();

    selectedPlan = 1;

    final title = widget.planTitle?.toLowerCase();

    if (title != null) {
      if (title.contains('1 tháng')) {
        selectedPlan = 0;
      } else if (title.contains('3 tháng')) {
        selectedPlan = 1;
      } else if (title.contains('6 tháng')) {
        selectedPlan = 2;
      }
    }
  }

  int get selectedPrice {
    if (widget.planPrice != null) {
      final digits =
      widget.planPrice!.replaceAll(RegExp(r'[^0-9]'), '');
      final parsedPrice = int.tryParse(digits);

      if (parsedPrice != null) {
        return parsedPrice;
      }
    }

    return plans[selectedPlan]['price'] as int;
  }

  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match.group(1)}.',
    )} đ';
  }

  void _showPaymentConfirmation() {
    final plan = Map<String, dynamic>.from(plans[selectedPlan]);

    if (widget.planTitle != null) {
      plan['name'] = 'Gói ${widget.planTitle}';
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xác nhận thanh toán',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 22),
              _buildDetailRow(
                sheetContext,
                'Gói tập',
                plan['name'] as String,
              ),
              _buildDetailRow(
                sheetContext,
                'Thời hạn',
                plan['duration'] as String,
              ),
              _buildDetailRow(
                sheetContext,
                'Phương thức',
                selectedPaymentMethod,
              ),
              Divider(
                height: 28,
                color: colors.onSurface.withValues(alpha: 0.12),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tổng thanh toán',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.7),
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    _formatPrice(selectedPrice),
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onPaymentSuccess?.call({
                      'planName': plan['name'].toString(),
                      'duration': plan['duration'].toString(),
                      'price': selectedPrice,
                      'paymentMethod': selectedPaymentMethod,
                      'paidAt': DateTime.now().toIso8601String(),
                    });

                    Navigator.pop(sheetContext);
                    Navigator.pop(this.context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Xác nhận thanh toán',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
      BuildContext context,
      String title,
      String value,
      ) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gia hạn & thanh toán',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMembershipStatus(context),
              const SizedBox(height: 24),
              Text(
                'Chọn gói gia hạn',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              ...List.generate(
                plans.length,
                    (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPlanCard(
                    context: context,
                    plan: plans[index],
                    index: index,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Phương thức thanh toán',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              ...paymentMethods.map(
                    (method) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildPaymentMethod(context, method),
                ),
              ),
              const SizedBox(height: 14),
              _buildPaymentNote(context),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showPaymentConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Thanh toán ${_formatPrice(selectedPrice)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipStatus(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.22),
            colors.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.card_membership,
            color: colors.primary,
            size: 34,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gói hiện tại',
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'FitCenter Premium',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Còn 12 ngày sử dụng',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required Map<String, dynamic> plan,
    required int index,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = selectedPlan == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlan = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.15)
                    : colors.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.38),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan['name'] as String,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    plan['description'] as String,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.54),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _formatPrice(plan['price'] as int),
              style: TextStyle(
                color: isSelected ? colors.primary : colors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod(
      BuildContext context,
      Map<String, dynamic> method,
      ) {
    final colors = Theme.of(context).colorScheme;
    final name = method['name'] as String;
    final isSelected = selectedPaymentMethod == name;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPaymentMethod = name;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              method['icon'] as IconData,
              color: isSelected
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    method['subtitle'] as String,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.54),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentNote(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: colors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đây là giao diện thanh toán mô phỏng. '
                  'Khi backend và Payment Gateway được tích hợp, '
                  'giao dịch thực tế sẽ được xử lý tại đây.',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}