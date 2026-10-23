
import 'package:flutter/material.dart';

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({super.key});

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  final List<Map<String, dynamic>> _slots = [
    {
      'date': DateTime(2026, 10, 24),
      'start': '08:00',
      'end': '09:30',
      'booked': false,
    },
    {
      'date': DateTime(2026, 10, 24),
      'start': '10:00',
      'end': '11:30',
      'booked': true,
    },
    {
      'date': DateTime(2026, 10, 25),
      'start': '14:00',
      'end': '15:30',
      'booked': false,
    },
  ];

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isPastDate(DateTime date) =>
      _dateOnly(date).isBefore(_dateOnly(DateTime.now()));

  int _minutesFromTime(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool _hasStartedOrPassed(Map<String, dynamic> slot) {
    final date = slot['date'] as DateTime;

    if (_isPastDate(date)) return true;

    if (_dateOnly(date) == _dateOnly(DateTime.now())) {
      final now = TimeOfDay.now();
      final nowMinutes = now.hour * 60 + now.minute;
      return _minutesFromTime(slot['start'] as String) <= nowMinutes;
    }

    return false;
  }

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
    final isEditing = index != null;

    if (isEditing && (index < 0 || index >= _slots.length)) return;

    final existingSlot = isEditing ? _slots[index] : null;

    if (existingSlot != null) {
      if (existingSlot['booked'] == true) {
        _showMessage('Khung giờ đã được đặt nên không thể chỉnh sửa.');
        return;
      }

      if (_hasStartedOrPassed(existingSlot)) {
        _showMessage(
          'Không thể chỉnh sửa khung giờ đã bắt đầu hoặc đã qua.',
        );
        return;
      }
    }

    DateTime selectedDate =
        existingSlot?['date'] as DateTime? ?? _dateOnly(DateTime.now());

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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> chooseDate() async {
              final today = _dateOnly(DateTime.now());

              final pickedDate = await showDatePicker(
                context: dialogContext,
                initialDate:
                selectedDate.isBefore(today) ? today : selectedDate,
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

                    final endMinutes =
                        selectedEnd!.hour * 60 + selectedEnd!.minute;

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

                    final startDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedStart!.hour,
                      selectedStart!.minute,
                    );

                    if (startDateTime.isBefore(DateTime.now())) {
                      setDialogState(() {
                        validationMessage =
                        'Không thể tạo hoặc chuyển lịch về thời gian đã qua.';
                      });
                      return;
                    }

                    final hasConflict = _slots.asMap().entries.any((entry) {
                      if (isEditing && entry.key == index) {
                        return false;
                      }

                      final slot = entry.value;
                      final slotDate = slot['date'] as DateTime;

                      if (slotDate.year != selectedDate.year ||
                          slotDate.month != selectedDate.month ||
                          slotDate.day != selectedDate.day) {
                        return false;
                      }

                      final oldStart =
                      _minutesFromTime(slot['start'] as String);
                      final oldEnd =
                      _minutesFromTime(slot['end'] as String);

                      return startMinutes < oldEnd &&
                          endMinutes > oldStart;
                    });

                    if (hasConflict) {
                      setDialogState(() {
                        validationMessage =
                        'Khung giờ bị trùng với lịch đã có.';
                      });
                      return;
                    }

                    final newSlot = <String, dynamic>{
                      'date': _dateOnly(selectedDate),
                      'start': _formatTime(selectedStart),
                      'end': _formatTime(selectedEnd),
                      'booked': existingSlot?['booked'] == true,
                    };

                    setState(() {
                      if (isEditing) {
                        _slots[index] = newSlot;
                      } else {
                        _slots.add(newSlot);
                      }

                      _slots.sort((a, b) {
                        final dateCompare = (a['date'] as DateTime)
                            .compareTo(b['date'] as DateTime);

                        if (dateCompare != 0) return dateCompare;

                        return (a['start'] as String)
                            .compareTo(b['start'] as String);
                      });
                    });

                    Navigator.pop(dialogContext);

                    _showMessage(
                      isEditing
                          ? 'Đã cập nhật khung giờ.'
                          : 'Đã tạo khung giờ làm.',
                    );
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSlot(int index) async {
    if (index < 0 || index >= _slots.length) return;

    final slot = _slots[index];

    if (slot['booked'] == true) {
      _showMessage('Không thể xóa khung giờ đã được đặt.');
      return;
    }

    if (_hasStartedOrPassed(slot)) {
      _showMessage(
        'Không thể xóa khung giờ đã bắt đầu hoặc đã qua.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa khung giờ'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa khung giờ này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _slots.removeAt(index));
      _showMessage('Đã xóa khung giờ.');
    }
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
            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  size: 32,
                  color: colors.primary,
                ),
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
              onPressed: () => _showSlotDialog(),
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
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_slots.isEmpty)
              _buildEmptyState(context)
            else
              ...List.generate(
                _slots.length,
                    (index) => _buildSlotCard(
                  context,
                  index,
                  _slots[index],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Dữ liệu lịch hiện là dữ liệu mẫu trên thiết bị.',
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
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
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
    final canManage = !isBooked && !isLocked;

    return Container(
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
              Icon(
                Icons.calendar_today,
                color: colors.primary,
                size: 20,
              ),
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
                enabled: canManage,
                onSelected: (value) {
                  if (value == 'edit') {
                    _showSlotDialog(index: index);
                  } else if (value == 'delete') {
                    _deleteSlot(index);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Chỉnh sửa'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa'),
                  ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo khung giờ để bắt đầu nhận học viên.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
