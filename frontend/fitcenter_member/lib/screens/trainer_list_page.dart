import 'package:flutter/material.dart';

import '../widgets/page_header.dart';
import '../services/booking_state.dart';
import '../widgets/api_status.dart';
import 'trainer_detail_page.dart';

class TrainerListPage extends StatelessWidget {
  final BookingState state;
  final ValueChanged<String> onShowMessage;
  final ValueChanged<String> onSelectTrainerForBooking;

  const TrainerListPage({
    super.key,
    required this.onShowMessage,
    required this.state,
    required this.onSelectTrainerForBooking,
  });

  List<Map<String, dynamic>> get trainers => state.trainers
      .map(
        (t) => {
          'id': t.id,
          'name': t.fullName,
          'specialty': t.specialization ?? 'Chưa có thông tin',
          'experience': t.experienceSummary ?? 'Chưa có thông tin',
          'rating': 'Chưa khả dụng',
          'sessions': 'Chưa khả dụng',
          'initials': t.fullName
              .trim()
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .take(2)
              .map((s) => s[0])
              .join(),
        },
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                icon: Icons.fitness_center,
                title: 'Huấn luyện viên',
                subtitle: 'Tìm PT phù hợp với mục tiêu của bạn',
              ),
              ApiStatus(state: state),
              const SizedBox(height: 22),
              _buildIntroCard(context),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Danh sách PT',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${trainers.length} huấn luyện viên',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!state.loading && trainers.isEmpty)
                const Text('Chưa có huấn luyện viên để hiển thị.'),
              ...trainers.map((trainer) => _buildTrainerCard(context, trainer)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.track_changes, color: colors.primary, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chinh phục mục tiêu của bạn',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chọn huấn luyện viên phù hợp và lên lịch tập riêng.',
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
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

  Widget _buildTrainerCard(BuildContext context, Map<String, dynamic> trainer) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    trainer['initials'] as String,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer['name'] as String,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      trainer['specialty'] as String,
                      style: TextStyle(color: colors.primary, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      trainer['experience'] as String,
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: colors.onSurface.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.star, color: colors.primary, size: 18),
              const SizedBox(width: 5),
              Text(
                trainer['rating'] as String,
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.fitness_center,
                color: colors.onSurface.withValues(alpha: 0.55),
                size: 17,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  trainer['sessions'] as String,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: ValueKey('trainer-${trainer['id']}'),
              onPressed: state.blocked
                  ? null
                  : () => state.act(() async {
                      final detail = await state.service.trainer(
                        trainer['id'] as String,
                      );
                      if (!context.mounted || !state.alive) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TrainerDetailPage(
                            trainerName: detail.fullName,
                            specialty:
                                detail.specialization ?? 'Chưa có thông tin',
                            experience:
                                detail.experienceSummary ?? 'Chưa có thông tin',
                            rating: 'Chưa khả dụng',
                            sessions: 'Chưa khả dụng',
                            bio: detail.bio,
                            onShowMessage: onShowMessage,
                            onBookAppointment: () {
                              Navigator.pop(context);
                              onSelectTrainerForBooking(detail.id);
                            },
                          ),
                        ),
                      );
                    }),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Xem hồ sơ PT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
