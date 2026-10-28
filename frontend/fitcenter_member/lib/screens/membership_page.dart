import 'package:flutter/material.dart';

import '../widgets/detail_row.dart';
import '../widgets/page_header.dart';
import '../widgets/section_title.dart';
import 'renewal_payment_page.dart';

class MembershipPage extends StatelessWidget {
  final ValueChanged<String> onShowMessage;
  final ValueChanged<Map<String, dynamic>>? onPaymentSuccess;

  final Map<String, dynamic>? currentMembership;
  final List<Map<String, dynamic>> renewalHistory;

  const MembershipPage({
    super.key,
    required this.onShowMessage,
    this.onPaymentSuccess,
    this.currentMembership,
    this.renewalHistory = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                icon: Icons.card_membership,
                title: 'Gói hội viên',
                subtitle: 'Quản lý gói tập của bạn',
              ),
              const SizedBox(height: 24),
              _buildMembershipCard(context),
              const SizedBox(height: 28),
              const SectionTitle('Tình trạng sử dụng'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      icon: Icons.fitness_center_rounded,
                      value: '12',
                      label: 'Buổi đã tập',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      icon: Icons.event_available_rounded,
                      value: '18',
                      label: 'Ngày còn lại',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SectionTitle('Gia hạn gói hội viên'),
              const SizedBox(height: 12),
              _buildRenewalCard(context),
              const SizedBox(height: 28),
              const SectionTitle('Lịch sử gia hạn'),
              const SizedBox(height: 12),
              _buildPaymentHistory(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipCard(BuildContext context) {
    final membership = currentMembership;

    final planName =
        membership?['planName']?.toString() ?? 'Gói cao cấp';

    final duration =
        membership?['duration']?.toString() ?? '3 tháng';

    final paidAt = membership?['paidAt']?.toString();

    final startDateText = membership?['startDate']?.toString();
    final expiryDateText = membership?['expiryDate']?.toString();

    final startDate = startDateText != null
        ? DateTime.tryParse(startDateText)
        : (paidAt != null ? DateTime.tryParse(paidAt) : null);

    final expiryDate = expiryDateText != null
        ? DateTime.tryParse(expiryDateText)
        : startDate != null
        ? startDate.add(
      Duration(
        days: duration.contains('180')
            ? 180
            : duration.contains('90')
            ? 90
            : 30,
      ),
    )
        : (membership == null ? DateTime(2026, 11, 8) : null);

    final remainingDays = expiryDate == null
        ? 18
        : expiryDate.difference(DateTime.now()).inDays.clamp(0, 9999);

    final isActive =
        expiryDate != null && expiryDate.isAfter(DateTime.now());

    String formatDate(DateTime? date, String fallback) {
      if (date == null) return fallback;

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 26,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.red,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isActive ? 'ĐÃ KÍCH HOẠT' : 'ĐÃ HẾT HẠN',
                      style: TextStyle(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            planName.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gói tập $duration',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08),
          ),
          const SizedBox(height: 16),
          DetailRow(
            'Ngày bắt đầu',
            formatDate(startDate, '01/10/2026'),
          ),
          const SizedBox(height: 12),
          DetailRow(
            'Ngày hết hạn',
            formatDate(expiryDate, '08/11/2026'),
          ),
          const SizedBox(height: 12),
          DetailRow(
            'Thời hạn còn lại',
            '$remainingDays ngày',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context, {
        required IconData icon,
        required String value,
        required String label,
      }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenewalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.autorenew_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gia hạn gói tập',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chọn gói phù hợp với nhu cầu của bạn',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _showRenewalSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Xem gói gia hạn',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory(BuildContext context) {
    final hasNewPayments = renewalHistory.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (hasNewPayments)
            for (int i = 0; i < renewalHistory.length; i++) ...[
              _buildPaymentItem(
                context,
                date: _formatPaymentDate(
                  renewalHistory[i]['paidAt']?.toString(),
                ),
                title: renewalHistory[i]['planName']
                    ?.toString()
                    .toUpperCase() ??
                    'GÓI HỘI VIÊN',
                amount:
                '${_formatPaymentPrice(renewalHistory[i]['price'])} đ',
                status: 'THÀNH CÔNG',
              ),
              Divider(
                height: 1,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
              ),
            ],
          if (!hasNewPayments)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 36,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Chưa có lịch sử thanh toán',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatPaymentDate(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);

    if (date == null) return '--/--/----';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatPaymentPrice(dynamic value) {
    final price = (value as num?)?.round();

    if (price == null) return '0';

    final digits = price.toString();
    final result = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        result.write('.');
      }
      result.write(digits[i]);
    }

    return result.toString();
  }

  Widget _buildPaymentItem(
      BuildContext context, {
        required String date,
        required String title,
        required String amount,
        required String status,
      }) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.54),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRenewalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Chọn gói gia hạn',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gói hội viên hiện tại sẽ được nối tiếp sau ngày hết hạn.',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.54),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                _buildPlanOption(
                  sheetContext,
                  pageContext: context,
                  title: '1 tháng',
                  subtitle: 'Phù hợp để gia hạn ngắn hạn',
                  price: '500.000 đ',
                ),
                const SizedBox(height: 12),
                _buildPlanOption(
                  sheetContext,
                  pageContext: context,
                  title: '3 tháng',
                  subtitle: 'Lựa chọn phổ biến',
                  price: '1.500.000 đ',
                  recommended: true,
                ),
                const SizedBox(height: 12),
                _buildPlanOption(
                  sheetContext,
                  pageContext: context,
                  title: '6 tháng',
                  subtitle: 'Tiết kiệm cho kế hoạch dài hạn',
                  price: '2.700.000 đ',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanOption(
      BuildContext context, {
        required BuildContext pageContext,
        required String title,
        required String subtitle,
        required String price,
        bool recommended = false,
      }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.pop(context);

        Navigator.of(pageContext).push(
          MaterialPageRoute<void>(
            builder: (_) => RenewalPaymentPage(
              planTitle: title,
              planPrice: price,
              onPaymentSuccess: (payment) {
                onPaymentSuccess?.call(payment);
              },
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: recommended
                ? Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.45)
                : Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ĐỀ XUẤT',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.54),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              price,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}