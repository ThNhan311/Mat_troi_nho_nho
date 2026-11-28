import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/booking_models.dart';
import '../services/vietnam_time.dart';
import 'trainer_photo.dart';

/// The separate specialties of "Yoga, Cardio".
List<String> splitSpecialties(String? value) => (value ?? '')
    .split(',')
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();

List<String> specialtiesOf(Trainer trainer) =>
    splitSpecialties(trainer.specialization);

String weekdayName(DateTime instant) => const [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
][vietnamDate(instant).weekday - 1];

String? _filled(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Null when the server did not say; it is never guessed.
String? genderText(String? gender) =>
    const {'MALE': 'Nam', 'FEMALE': 'Nữ'}[gender];

String? experienceText(String? experience) {
  final years = _filled(experience);
  return years == null ? null : 'Kinh nghiệm: $years';
}

/// What the server said about a trainer's free sessions.
class OpenSlots {
  const OpenSlots(this.upcoming);

  /// Free sessions still to come, earliest first.
  final List<Slot> upcoming;

  DateTime? get next => upcoming.firstOrNull?.startAt;
}

/// Who the trainer is and when they are free.
class TrainerShowcaseCard extends StatelessWidget {
  const TrainerShowcaseCard({
    super.key,
    required this.trainer,
    required this.api,
    required this.onOpenProfile,
    required this.onBook,
    this.open,
  });

  final Trainer trainer;
  final ApiClient api;
  final VoidCallback? onOpenProfile, onBook;

  /// Null until the server answers, and after a failed read.
  final OpenSlots? open;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final specialties = specialtiesOf(trainer);
    final gender = genderText(trainer.gender);
    final experience = experienceText(trainer.experienceSummary);
    final muted = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 13.5,
      height: 1.4,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onOpenProfile,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrainerPhoto(
                  key: ValueKey('trainer-avatar-${trainer.id}'),
                  api: api,
                  id: trainer.id,
                  name: trainer.fullName,
                  size: 68,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The gender sits small in the top right corner.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              trainer.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (gender != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              gender,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        specialties.isEmpty
                            ? 'Chưa cập nhật chuyên môn'
                            : specialties.join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                      if (experience != null)
                        Text(
                          experience,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (open case final free?) ...[
            Divider(height: 22, color: colors.outlineVariant),
            _nextSlot(muted, free),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('trainer-${trainer.id}'),
                  onPressed: onOpenProfile,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Xem hồ sơ PT'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: ValueKey('book-trainer-${trainer.id}'),
                  onPressed: onBook,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Đặt lịch'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nextSlot(TextStyle muted, OpenSlots free) {
    final next = free.next;
    if (next == null) {
      return Text('Chưa có lịch trống trong thời gian tới', style: muted);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lịch trống gần nhất', style: muted),
        Text(
          '${weekdayName(next)}, ${vietnamDateText(next).substring(0, 5)} • '
          '${vietnamClock(next)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
