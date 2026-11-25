import 'package:flutter/material.dart';

class TrainerDetailPage extends StatelessWidget {
  final String trainerName;
  final String? bio;
  final String specialty;
  final String experience;
  final String rating;
  final String sessions;
  final ValueChanged<String> onShowMessage;
  final VoidCallback onBookAppointment;

  const TrainerDetailPage({
    super.key,
    required this.trainerName,
    this.bio,
    required this.specialty,
    required this.experience,
    required this.rating,
    required this.sessions,
    required this.onShowMessage,
    required this.onBookAppointment,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Hồ sơ huấn luyện viên')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, size: 65, color: colors.primary),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  trainerName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  specialty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.primary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildStat(context, 'Đánh giá', rating, Icons.star),
                  const SizedBox(width: 10),
                  _buildStat(
                    context,
                    'Kinh nghiệm',
                    experience,
                    Icons.work_outline,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildInfoCard(
                context,
                icon: Icons.fitness_center,
                title: 'Giới thiệu',
                content: bio ?? 'Chưa có thông tin',
              ),
              const SizedBox(height: 14),
              _buildInfoCard(
                context,
                icon: Icons.track_changes,
                title: 'Chuyên môn',
                content: specialty,
              ),
              const SizedBox(height: 14),
              _buildInfoCard(
                context,
                icon: Icons.calendar_month,
                title: 'Lịch huấn luyện',
                content:
                    'Xem các khung giờ còn trống và chọn lịch phù hợp với bạn.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onBookAppointment,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Chọn lịch tập với PT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  Widget _buildStat(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.primary, size: 22),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  content,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
