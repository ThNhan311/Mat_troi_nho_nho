import 'package:flutter/material.dart';

import '../services/booking_state.dart';
import '../services/booking_models.dart';
import '../services/vietnam_time.dart';
import '../widgets/api_status.dart';

class AvailabilityPage extends StatefulWidget {
  final BookingState state;
  const AvailabilityPage({super.key, required this.state});

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  List<Map<String, dynamic>> get _slots => widget.state.availability;
  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
  bool _hasStartedOrPassed(Map<String, dynamic> slot) => false;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Chưa chọn';

    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSlotDialog({int? index}) async {
    await widget.state.act(() async {
      final isEditing = index != null;

      if (isEditing && (index < 0 || index >= _slots.length)) return;

      final existingSlot = isEditing ? _slots[index] : null;

      if (existingSlot != null) {
        if (existingSlot['booked'] == true) {
          _showMessage('Khung giờ đã được đặt nên không thể chỉnh sửa.');
          return;
        }

        if (_hasStartedOrPassed(existingSlot)) {
          _showMessage('Không thể chỉnh sửa khung giờ đã bắt đầu hoặc đã qua.');
          return;
        }
      }

      DateTime selectedDate =
          existingSlot?['date'] as DateTime? ??
          vietnamDate(DateTime.now().toUtc());

      TimeOfDay? selectedStart;
      TimeOfDay? selectedEnd;

      if (existingSlot != null) {
        final startParts = (existingSlot['start'] as String).split(':');
        final endParts = (existingSlot['end'] as String).split(':');

        selectedStart = TimeOfDay(
          hour: int.parse(startParts[0]),
          minute: int.parse(startParts[1]),
        );

        selectedEnd = TimeOfDay(
          hour: int.parse(endParts[0]),
          minute: int.parse(endParts[1]),
        );
      }

      String? validationMessage;

      final start = await showDialog<DateTime>(
        useRootNavigator: false,
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> chooseDate() async {
                final today = vietnamDate(DateTime.now().toUtc());

                final pickedDate = await showDatePicker(
                  useRootNavigator: false,
                  context: dialogContext,
                  initialDate: selectedDate.isBefore(today)
                      ? today
                      : selectedDate,
                  firstDate: today,
                  lastDate: today.add(const Duration(days: 365)),
                );

                if (pickedDate != null) {
                  setDialogState(() {
                    selectedDate = _dateOnly(pickedDate);
                    validationMessage = null;
                  });
                }
              }

              Future<void> chooseTime({required bool isStart}) async {
                final initialTime = isStart
                    ? (selectedStart ?? const TimeOfDay(hour: 8, minute: 0))
                    : (selectedEnd ?? const TimeOfDay(hour: 9, minute: 30));

                final pickedTime = await showTimePicker(
                  useRootNavigator: false,
                  context: dialogContext,
                  initialTime: initialTime,
                );

                if (pickedTime != null) {
                  setDialogState(() {
                    if (isStart) {
                      selectedStart = pickedTime;
                    } else {
                      selectedEnd = pickedTime;
                    }

                    validationMessage = null;
                  });
                }
              }

              return AlertDialog(
                title: Text(
                  isEditing ? 'Chỉnh sửa khung giờ' : 'Tạo khung giờ làm',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ngày tập'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: chooseDate,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_month),
                          ),
                          child: Text(_formatDate(selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Giờ bắt đầu'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => chooseTime(isStart: true),
                        icon: const Icon(Icons.access_time),
                        label: Text(_formatTime(selectedStart)),
                      ),
                      const SizedBox(height: 12),
                      const Text('Giờ kết thúc'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => chooseTime(isStart: false),
                        icon: const Icon(Icons.access_time),
                        label: Text(_formatTime(selectedEnd)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mỗi khung giờ phải kéo dài đúng 90 phút.',
                        style: TextStyle(fontSize: 12),
                      ),
                      if (validationMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          validationMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (selectedStart == null || selectedEnd == null) {
                        setDialogState(() {
                          validationMessage =
                              'Vui lòng chọn giờ bắt đầu và giờ kết thúc.';
                        });
                        return;
                      }

                      final startMinutes =
                          selectedStart!.hour * 60 + selectedStart!.minute;

                      var endMinutes =
                          selectedEnd!.hour * 60 + selectedEnd!.minute;

                      if (endMinutes <= startMinutes) endMinutes += 24 * 60;
                      if (endMinutes <= startMinutes) {
                        setDialogState(() {
                          validationMessage =
                              'Giờ kết thúc phải sau giờ bắt đầu.';
                        });
                        return;
                      }

                      if (endMinutes - startMinutes != 90) {
                        setDialogState(() {
                          validationMessage =
                              'Mỗi khung giờ phải kéo dài đúng 90 phút.';
                        });
                        return;
                      }

                      final startDateTime = parseVietnamInput(
                        '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} ${_formatTime(selectedStart)}',
                      );
                      Navigator.pop(dialogContext, startDateTime);
                    },
                    child: const Text('Lưu'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (start != null && mounted && widget.state.alive)
        await widget.state.saveSlot(
          start,
          previous: existingSlot?['dto'] as Slot?,
        );
    });
  }

  Future<void> _deleteSlot(int index) async {
    await widget.state.act(() async {
      if (index < 0 || index >= _slots.length) return;

      final slot = _slots[index];

      if (slot['booked'] == true) {
        _showMessage('Không thể xóa khung giờ đã được đặt.');
        return;
      }

      if (_hasStartedOrPassed(slot)) {
        _showMessage('Không thể xóa khung giờ đã bắt đầu hoặc đã qua.');
        return;
      }

      final confirmed = await showDialog<bool>(
        useRootNavigator: false,
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Xóa khung giờ'),
          content: const Text('Bạn có chắc chắn muốn xóa khung giờ này không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Giữ lại'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted && widget.state.alive)
        await widget.state.remove(slot['dto'] as Slot);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ApiStatus(state: widget.state),
            Row(
              children: [
                Icon(Icons.calendar_month, size: 32, color: colors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quản lý lịch làm',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('Các khung giờ nhận học viên'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('create-slot'),
              onPressed: widget.state.blocked ? null : () => _showSlotDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Tạo khung giờ làm'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    title: 'Chưa được đặt',
                    value: _slots
                        .where((slot) => slot['booked'] == false)
                        .length
                        .toString(),
                    icon: Icons.event_available,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    title: 'Đã được đặt',
                    value: _slots
                        .where((slot) => slot['booked'] == true)
                        .length
                        .toString(),
                    icon: Icons.event_busy,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Danh sách khung giờ',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_slots.isEmpty)
              _buildEmptyState(context)
            else
              ...List.generate(
                _slots.length,
                (index) => _buildSlotCard(context, index, _slots[index]),
              ),
            const SizedBox(height: 16),
            Text(
              'Giờ hiển thị theo Việt Nam (UTC+07:00).',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    int index,
    Map<String, dynamic> slot,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isBooked = slot['booked'] == true;
    final date = slot['date'] as DateTime;
    final isLocked = _hasStartedOrPassed(slot);
    final canManage = !isBooked && !isLocked && !widget.state.blocked;

    return Container(
      key: ValueKey('availability-${slot['id']}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBooked
              ? Colors.orange.withValues(alpha: 0.35)
              : Colors.green.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('slot-menu-${slot['id']}'),
                tooltip: 'Thao tác khung giờ ${shortId(slot['id'] as String)}',
                enabled: canManage,
                onSelected: (value) {
                  if (value == 'edit') {
                    _showSlotDialog(index: index);
                  } else if (value == 'delete') {
                    _deleteSlot(index);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 20),
              const SizedBox(width: 8),
              Text(
                '${slot['start']} - ${slot['end']}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isBooked
                  ? Colors.orange.withValues(alpha: 0.12)
                  : Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isBooked ? 'Đã được đặt' : 'Chưa được đặt',
              style: TextStyle(
                color: isBooked ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          if (isBooked || isLocked) ...[
            const SizedBox(height: 8),
            Text(
              isBooked
                  ? 'Khung giờ đã được đặt nên không thể chỉnh sửa hoặc xóa.'
                  : 'Khung giờ đã bắt đầu hoặc đã qua nên không thể chỉnh sửa hoặc xóa.',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa có khung giờ làm',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo khung giờ để bắt đầu nhận học viên.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}
