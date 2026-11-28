import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/booking_models.dart';
import '../services/vietnam_time.dart';
import '../widgets/trainer_photo.dart';
import '../widgets/trainer_showcase_card.dart';

/// One trainer: the photo, who they are, how to reach them and when they are
/// free. The booking button stays on screen.
class TrainerDetailPage extends StatelessWidget {
  final String trainerName;

  /// The round picture; the initials stand in when there is none.
  final Widget? photo;
  final String? bio, specialization, experience, phone, gender;

  /// Null when the server has not said; then nothing is claimed about it.
  final List<Slot>? slots;
  final ValueChanged<String> onShowMessage;
  final VoidCallback onBookAppointment;

  const TrainerDetailPage({
    super.key,
    required this.trainerName,
    this.photo,
    this.bio,
    this.specialization,
    this.experience,
    this.phone,
    this.gender,
    this.slots,
    required this.onShowMessage,
    required this.onBookAppointment,
  });

  static const photoSize = 112.0;
  static const _shownSlots = 4;

  static String? _filled(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final specialties = splitSpecialties(specialization);
    final sex = genderText(gender);
    final years = experienceText(experience);
    final about = _filled(bio);
    final number = _filled(phone);
    final muted = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 14,
      height: 1.5,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ huấn luyện viên')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: onBookAppointment,
                  child: const Text('Chọn lịch tập với PT'),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child:
                        photo ?? TrainerInitials(trainerName, size: photoSize),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          trainerName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (sex != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          sex,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (years != null)
                    Text(
                      years,
                      textAlign: TextAlign.center,
                      style: muted.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (specialties.isEmpty)
                    Text(
                      'Chưa cập nhật chuyên môn',
                      textAlign: TextAlign.center,
                      style: muted,
                    )
                  else
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in specialties) _tag(context, item),
                      ],
                    ),
                  const SizedBox(height: 18),
                  _section(context, [
                    _heading('Giới thiệu'),
                    const SizedBox(height: 4),
                    Text(about ?? 'Chưa có phần giới thiệu.', style: muted),
                  ]),
                  _section(context, [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Số điện thoại', style: muted),
                              Text(
                                number ?? 'Chưa có thông tin',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (number != null)
                          OutlinedButton(
                            key: const Key('copy-phone'),
                            onPressed: () => _copy(context, number),
                            child: const Text('Sao chép'),
                          ),
                      ],
                    ),
                  ]),
                  if (slots case final free?)
                    _slotSection(context, free, muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String number) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: number));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Đã sao chép số điện thoại.')),
      );
  }

  Widget _heading(String text) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  );

  Widget _section(BuildContext context, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _tag(BuildContext context, String label) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _slotSection(BuildContext context, List<Slot> free, TextStyle muted) {
    final colors = Theme.of(context).colorScheme;
    final more = free.length - _shownSlots;
    return _section(context, [
      _heading('Lịch trống sắp tới'),
      const SizedBox(height: 4),
      if (free.isEmpty)
        Text('Chưa có lịch trống trong thời gian tới', style: muted),
      for (final (index, slot) in free.take(_shownSlots).indexed) ...[
        if (index > 0) Divider(height: 1, color: colors.outlineVariant),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${weekdayName(slot.startAt)}, '
                  '${vietnamDateText(slot.startAt).substring(0, 5)}',
                  style: muted,
                ),
              ),
              Text(
                '${vietnamClock(slot.startAt)} - ${vietnamClock(slot.endAt)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
      if (more > 0) Text('Còn $more lịch khác', style: muted),
    ]);
  }
}
