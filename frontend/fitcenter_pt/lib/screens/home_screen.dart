
import 'package:flutter/material.dart';

import '../widgets/info_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSchedule,
    required this.onShowMessage,
  });

  final VoidCallback onOpenSchedule;
  final void Function(String message) onShowMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Tiêu đề trang chủ
          Row(
            children: [
              Icon(
                Icons.fitness_center,
                size: 38,
                color: colors.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FitCenter PT',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('PERSONAL TRAINER'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          const Text(
            'Xin chào, PT Nam!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Quản lý lịch tập và hỗ trợ học viên của bạn.',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.65),
            ),
          ),

          const SizedBox(height: 24),

          // Thẻ truy cập lịch làm việc
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LỊCH LÀM VIỆC',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Chủ động sắp xếp\nlịch nhận học viên',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onOpenSchedule,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.onSurface,
                  ),
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Quản lý lịch làm'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Tổng quan hôm nay',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          const Row(
            children: [
              Expanded(
                child: InfoCard(
                  icon: Icons.event_available,
                  title: 'Buổi tập',
                  value: '2',
                  subtitle: 'Hôm nay',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: InfoCard(
                  icon: Icons.people_outline,
                  title: 'Học viên',
                  value: '5',
                  subtitle: 'Đang theo dõi',
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
