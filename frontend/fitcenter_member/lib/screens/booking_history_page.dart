import 'package:flutter/material.dart';

import '../services/booking_state.dart';
import '../widgets/api_status.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({
    super.key,
    required this.state,
    this.onShowMessage,
  });

  final BookingState state;
  final ValueChanged<String>? onShowMessage;

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  List<Map<String, String>> get bookings => widget.state.history;

  String statusLabel(String status) {
    switch (status) {
      case 'CONFIRMED':
        return 'Đã xác nhận';
      case 'COMPLETED':
        return 'Đã hoàn thành';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Future<void> _showCancelDialog(int index) async {
    await widget.state.act(() async {
      final booking = bookings[index];
      final colors = Theme.of(context).colorScheme;

      final confirmed = await showDialog<bool>(
        useRootNavigator: false,
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: colors.surfaceContainerHighest,
            title: Text(
              'Hủy lịch tập',
              style: TextStyle(color: colors.onSurface),
            ),
            content: Text(
              'Bạn có chắc chắn muốn hủy buổi tập với '
              '${booking['trainer']} vào ${booking['date']} '
              'lúc ${booking['time']}?',
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Không'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text(
                  'Hủy lịch',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      if (!mounted || !widget.state.alive) return;
      await widget.state.cancel(booking['id']!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Lịch sử đặt lịch'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ApiStatus(state: widget.state),
          Text(
            'Các buổi tập PT của bạn',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Theo dõi trạng thái các buổi tập đã đặt.',
            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 20),
          if (bookings.isEmpty)
            _buildEmptyState(context)
          else
            for (int index = 0; index < bookings.length; index++)
              _buildBookingCard(context, bookings[index], index),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.54),
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có lịch đặt nào',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Các buổi tập PT của bạn sẽ hiển thị tại đây.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
    BuildContext context,
    Map<String, String> booking,
    int index,
  ) {
    final colors = Theme.of(context).colorScheme;
    final status = booking['status']!;
    final isConfirmed = status == 'CONFIRMED';

    return Card(
      key: ValueKey('history-${booking['id']}'),
      color: colors.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center, color: colors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    booking['trainer']!,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, Icons.calendar_today, booking['date']!),
            const SizedBox(height: 10),
            _buildInfoRow(context, Icons.access_time, booking['time']!),
            const SizedBox(height: 8),
            Text('Mã đặt lịch: ${booking['id']}'),
            if (booking['reason'] != null) Text('Lý do: ${booking['reason']}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusLabel(status),
                    style: TextStyle(
                      color: isConfirmed
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isConfirmed)
                  TextButton(
                    onPressed: widget.state.blocked
                        ? null
                        : () => _showCancelDialog(index),
                    child: const Text(
                      'Hủy lịch',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}
