import 'package:flutter/material.dart';

import '../widgets/feature_tile.dart';
import '../widgets/info_card.dart';
import '../widgets/api_status.dart';
import '../services/booking_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.state,
    required this.bookingConfirmed,
    this.bookingCount,
    required this.onOpenSchedule,
    required this.onOpenMembership,
    required this.onShowMessage,
  });

  final bool bookingConfirmed;
  final int? bookingCount;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenMembership;
  final void Function(String message) onShowMessage;

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrandHeader(context),
            ApiStatus(state: state),
            const SizedBox(height: 32),
            const Text(
              'Xin chào!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sẵn sàng cho buổi tập hôm nay chưa?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            _buildHeroCard(context),
            const SizedBox(height: 30),
            const Text(
              'Tổng quan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InfoCard(
                    icon: Icons.local_fire_department,
                    title: 'Buổi tập',
                    value: bookingCount?.toString() ?? '—',
                    subtitle: 'Trong khoảng xem',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoCard(
                    icon: Icons.schedule,
                    title: 'Thời lượng',
                    value: bookingCount == null
                        ? '—'
                        : '${bookingCount! * 1.5} giờ',
                    subtitle: 'Trong khoảng xem',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Khám phá FitCenter',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            FeatureTile(
              icon: Icons.card_membership,
              title: 'Gói tập của tôi',
              subtitle: 'Theo dõi thông tin hội viên',
              onTap: onOpenMembership,
            ),
            const SizedBox(height: 10),
            FeatureTile(
              icon: Icons.calendar_month,
              title: 'Lịch tập',
              subtitle: 'Quản lý lịch tập của bạn',
              onTap: onOpenSchedule,
            ),
            const SizedBox(height: 10),
            FeatureTile(
              icon: Icons.fitness_center,
              title: 'Kế hoạch tập luyện',
              subtitle: 'Xem và theo dõi chương trình tập',
              onTap: () => onShowMessage('Chưa khả dụng'),
            ),
            const SizedBox(height: 10),
            FeatureTile(
              icon: Icons.fact_check_outlined,
              title: 'Lịch sử điểm danh',
              subtitle: 'Theo dõi các buổi đã điểm danh',
              onTap: () => onShowMessage('Chưa khả dụng'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.fitness_center,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FitCenter',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                'YOUR FITNESS JOURNEY',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.55),
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => onShowMessage('Chưa khả dụng'),
          icon: const Icon(Icons.notifications_none),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BẮT ĐẦU NGAY',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Mỗi ngày\nmạnh mẽ hơn.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onOpenSchedule,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Đặt lịch tập'),
          ),
        ],
      ),
    );
  }
}
