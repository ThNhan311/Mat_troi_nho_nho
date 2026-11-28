import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import 'avatar.dart';

/// Who a student is and how to reach them, from one session record.
class StudentInfo extends StatelessWidget {
  const StudentInfo({
    super.key,
    required this.api,
    required this.session,
    this.avatarSize = 72,
  });

  final ApiClient api;

  /// A record from `BookingState.session`.
  final Map<String, dynamic> session;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 13.5,
      height: 1.4,
    );
    final name = '${session['memberName'] ?? 'Chưa có'}';
    final gender = const {
      'MALE': 'Nam',
      'FEMALE': 'Nữ',
    }[session['memberGender']];
    final phone = session['memberPhone'] as String?;
    final id = session['memberId'];
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            RemoteAvatar(
              key: const Key('student-avatar'),
              api: api,
              path: '/pt/booked-members/$id/avatar',
              size: avatarSize,
              fallback: CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  letters,
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: avatarSize * 0.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
                          name,
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
                  SelectionArea(
                    child: Text(
                      'Mã hội viên: ${session['memberCode'] ?? '—'}',
                      style: muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Divider(height: 24, color: colors.outlineVariant),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Số điện thoại', style: muted),
                  Text(
                    phone ?? 'Chưa có thông tin',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (phone != null)
              OutlinedButton(
                key: const Key('copy-phone'),
                onPressed: () => _copy(context, phone),
                child: const Text('Sao chép'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: phone));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Đã sao chép số điện thoại.')),
      );
  }
}
