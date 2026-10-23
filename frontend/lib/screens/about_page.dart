
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.onSurface),
        title: Text(
          'Về FitCenter',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.fitness_center,
                color: colors.primary,
                size: 52,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'FitCenter',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Phiên bản 1.0.0',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Giới thiệu',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'FitCenter là ứng dụng hỗ trợ hội viên theo dõi '
                        'lịch tập, đặt lịch, quản lý gói hội viên và '
                        'theo dõi tiến độ tập luyện.',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.7),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Các chức năng chính',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _FeatureItem(
                    icon: Icons.calendar_month,
                    title: 'Quản lý lịch tập',
                  ),
                  const _FeatureItem(
                    icon: Icons.card_membership,
                    title: 'Theo dõi gói hội viên',
                  ),
                  const _FeatureItem(
                    icon: Icons.fitness_center,
                    title: 'Kế hoạch và lịch sử tập luyện',
                  ),
                  const _FeatureItem(
                    icon: Icons.person_outline,
                    title: 'Quản lý thông tin cá nhân',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'FitCenter © 2026',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.38),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FeatureItem({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(
            icon,
            color: colors.primary,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
