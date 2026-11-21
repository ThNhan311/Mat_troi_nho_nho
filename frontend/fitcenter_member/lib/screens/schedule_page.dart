import 'package:flutter/material.dart';

import '../widgets/detail_row.dart';
import '../widgets/section_title.dart';

class SchedulePage extends StatefulWidget {
  final String? selectedTrainer;
  final String? selectedSlot;
  final bool bookingConfirmed;
  final bool isBookingSubmitting;
  final VoidCallback onBookingConfirmed;
  final ValueChanged<String> onTrainerSelected;
  final ValueChanged<String> onSlotSelected;
  final ValueChanged<DateTime> onDateSelected;

  const SchedulePage({
    super.key,
    required this.selectedTrainer,
    required this.selectedSlot,
    required this.bookingConfirmed,
    required this.isBookingSubmitting,
    required this.onBookingConfirmed,
    required this.onTrainerSelected,
    required this.onSlotSelected,
    required this.onDateSelected,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  // ============================================================
  // THÁNG HIỂN THỊ
  // ============================================================

  DateTime displayedMonth = DateTime(2026, 10);

  // Ngày đang được chọn
  DateTime? selectedDate;

  // PT đang được chọn
  String? selectedTrainer;

  // Khung giờ đang được chọn
  String? selectedSlot;
  String? selectedTrainerId;
  String? selectedSlotId;

  // ============================================================
  // DEMO DATA
  // Sau này sẽ lấy từ Backend API
  // ============================================================

  final List<Map<String, String>> trainers = [
    {
      'id': 'PT-001',
      'name': 'Nguyễn Minh Anh',
    },
    {
      'id': 'PT-002',
      'name': 'Trần Quốc Bảo',
    },
  ];

  final List<Map<String, String>> slots = [
    {
      'id': 'SLOT-20261025-0800',
      'time': '08:00 - 09:30',
    },
    {
      'id': 'SLOT-20261025-1000',
      'time': '10:00 - 11:30',
    },
    {
      'id': 'SLOT-20261025-1400',
      'time': '14:00 - 15:30',
    },
    {
      'id': 'SLOT-20261025-1600',
      'time': '16:00 - 17:30',
    },
    {
      'id': 'SLOT-20261025-1800',
      'time': '18:00 - 19:30',
    },
    {
      'id': 'SLOT-20261025-2000',
      'time': '20:00 - 21:30',
    },
  ];

  // Các ngày demo đã tập trong tháng 10/2026
  final Map<int, Map<String, String>> trainedDaysOctober = {
    1: {
      'time': '08:00 - 09:30',
      'type': 'Tự tập',
    },
    2: {
      'time': '18:00 - 19:30',
      'type': 'Tập cùng PT',
    },
    4: {
      'time': '14:00 - 15:30',
      'type': 'Tự tập',
    },
    6: {
      'time': '16:00 - 17:30',
      'type': 'Tập cùng PT',
    },
    7: {
      'time': '10:00 - 11:30',
      'type': 'Tự tập',
    },
    9: {
      'time': '18:00 - 19:30',
      'type': 'Tập cùng PT',
    },
    11: {
      'time': '08:00 - 09:30',
      'type': 'Tự tập',
    },
    13: {
      'time': '14:00 - 15:30',
      'type': 'Tập cùng PT',
    },
    15: {
      'time': '10:00 - 11:30',
      'type': 'Tự tập',
    },
    17: {
      'time': '18:00 - 19:30',
      'type': 'Tập cùng PT',
    },
    19: {
      'time': '16:00 - 17:30',
      'type': 'Tự tập',
    },
    21: {
      'time': '08:00 - 09:30',
      'type': 'Tập cùng PT',
    },
  };

  @override
  void initState() {
    super.initState();

    selectedTrainer = widget.selectedTrainer;
    selectedSlot = widget.selectedSlot;
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isPastDate(DateTime date) {
    return _dateOnly(date).isBefore(today);
  }

  bool _isToday(DateTime date) {
    return _dateOnly(date) == today;
  }

  bool _isSlotUnavailable(DateTime date, String slot) {
    // Không thể đặt lịch vào ngày đã qua.
    if (_isPastDate(date)) return true;

    // Lấy giờ bắt đầu, ví dụ "18:00" từ "18:00 - 19:30".
    final startTime = slot.split(' - ').first.split(':');

    final slotStart = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(startTime[0]),
      int.parse(startTime[1]),
    );

    // Khung giờ bắt đầu đúng lúc hiện tại cũng bị khóa.
    return !slotStart.isAfter(DateTime.now());
  }

  bool _isTrained(DateTime date) {
    if (date.year == 2026 && date.month == 10) {
      return trainedDaysOctober.containsKey(date.day);
    }

    return false;
  }

  // ============================================================
  // CALENDAR
  // ============================================================

  int _daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  int _firstWeekday(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);

    // Dart: Monday = 1 ... Sunday = 7
    return firstDay.weekday;
  }

  void _previousMonth() {
    setState(() {
      displayedMonth = DateTime(
        displayedMonth.year,
        displayedMonth.month - 1,
      );

      selectedDate = null;
      selectedTrainer = null;
      selectedSlot = null;
    });
  }

  void _nextMonth() {
    setState(() {
      displayedMonth = DateTime(
        displayedMonth.year,
        displayedMonth.month + 1,
      );

      selectedDate = null;
      selectedTrainer = null;
      selectedSlot = null;
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      selectedDate = date;

      // Khi đổi ngày phải chọn lại PT và slot.
      selectedTrainer = null;
      selectedSlot = null;
    });

    widget.onDateSelected(date);
  }

  // ============================================================
  // TRAINER / SLOT
  // ============================================================

  void _selectTrainer(String trainer) {
    if (selectedDate == null) return;

    if (_isPastDate(selectedDate!)) return;

    final selectedTrainerData = trainers.firstWhere(
          (item) => item['name'] == trainer,
    );

    setState(() {
      selectedTrainer = trainer;
      selectedTrainerId = selectedTrainerData['id'];
      selectedSlot = null;
      selectedSlotId = null;
    });

    widget.onTrainerSelected(trainer);
  }

  void _selectSlot(String slot) {
    if (selectedDate == null) return;

    if (_isPastDate(selectedDate!)) return;

    if (selectedTrainer == null) return;

    if (_isSlotUnavailable(selectedDate!, slot)) {
      _showMessage(
        'Khung giờ này đã bắt đầu hoặc đã qua. '
            'Vui lòng chọn khung giờ khác.',
      );
      return;
    }

    final selectedSlotData = slots.firstWhere(
          (item) => item['time'] == slot,
    );

    setState(() {
      selectedSlot = slot;
      selectedSlotId = selectedSlotData['id'];
    });

    widget.onSlotSelected(slot);
  }

  // ============================================================
  // BOOKING
  // ============================================================

  bool get canBook {
    if (selectedDate == null) return false;

    if (_isPastDate(selectedDate!)) return false;

    if (selectedTrainer == null) return false;

    if (selectedSlot == null) return false;

    if (_isSlotUnavailable(selectedDate!, selectedSlot!)) {
      return false;
    }

    return true;
  }

  void _showBookingConfirmation() {
    if (!canBook) {
      _showMessage('Vui lòng chọn đầy đủ PT và khung giờ.');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xác nhận đặt lịch',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 20),

              DetailRow(
                'Huấn luyện viên',
                selectedTrainer!,
              ),

              DetailRow(
                'Ngày',
                _formatDate(selectedDate!),
              ),

              DetailRow(
                'Khung giờ',
                selectedSlot!,
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lịch hợp lệ sẽ được xác nhận tự động sau khi hệ thống kiểm tra điều kiện đặt lịch.',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.isBookingSubmitting
                      ? null
                      : () {
                    Navigator.pop(context);
                    widget.onBookingConfirmed();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Xác nhận đặt lịch',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // FORMAT
  // ============================================================

  String _formatDate(DateTime date) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];

    return '${weekdays[date.weekday - 1]}, '
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12',
    ];

    return months[month - 1];
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _daysInMonth(displayedMonth);
    final firstWeekday = _firstWeekday(displayedMonth);

    final totalCells = ((firstWeekday - 1 + daysInMonth) / 7).ceil() * 7;

    final trainedCount = displayedMonth.year == 2026 &&
        displayedMonth.month == 10
        ? trainedDaysOctober.length
        : 0;

    final notTrainedCount = daysInMonth - trainedCount;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          32,
        ),
        children: [
          // ======================================================
          // HEADER
          // ======================================================

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch tập',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Theo dõi lịch tập và đặt lịch với PT',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ======================================================
          // STATISTICS
          // ======================================================

          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.check_circle_outline,
                  title: 'Đã tập',
                  value: '$trainedCount ngày',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.event_busy_outlined,
                  title: 'Chưa tập',
                  value: '$notTrainedCount ngày',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ======================================================
          // CALENDAR
          // ======================================================

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Month navigation
                Row(
                  children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: Icon(
                      Icons.chevron_left,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                    Expanded(
                      child: Center(
                        child: Text(
                          '${_monthName(displayedMonth.month)} ${displayedMonth.year}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: _nextMonth,
                      icon: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Weekday
                Row(
                  children: [
                    for (final day in [
                      'T2',
                      'T3',
                      'T4',
                      'T5',
                      'T6',
                      'T7',
                      'CN',
                    ])
                      Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Calendar grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalCells,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 4,
                  ),
                  itemBuilder: (context, index) {
                    final dayNumber =
                        index - (firstWeekday - 1) + 1;

                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return const SizedBox();
                    }

                    final date = DateTime(
                      displayedMonth.year,
                      displayedMonth.month,
                      dayNumber,
                    );

                    final isPast = _isPastDate(date);
                    final isToday = _isToday(date);
                    final isSelected = selectedDate != null &&
                        _dateOnly(selectedDate!) == _dateOnly(date);
                    final isTrained = _isTrained(date);

                    return GestureDetector(
                      onTap: () => _selectDate(date),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : isToday
                              ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isToday && !isSelected
                              ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                          )
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : isPast
                                    ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.3)
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: isToday || isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),

                            const SizedBox(height: 4),

                            if (isTrained)
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context)
                                      .colorScheme
                                      .onPrimary
                                      .withValues(alpha: 0.4)
                                      : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legend(
                      color: Theme.of(context).colorScheme.primary,
                      text: 'Đã tập',
                    ),
                    const SizedBox(width: 20),
                    _legend(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
                      text: 'Chưa tập',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ======================================================
          // SELECTED DATE
          // ======================================================

          if (selectedDate == null)
            _emptySelection()
          else
            _buildSelectedDateSection(),
        ],
      ),
    );
  }

  // ============================================================
  // SELECTED DATE SECTION
  // ============================================================

  Widget _buildSelectedDateSection() {
    final date = selectedDate!;
    final isPast = _isPastDate(date);
    final isToday = _isToday(date);
    final isTrained = _isTrained(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Ngày được chọn'),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.calendar_today_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isToday ? 'Hôm nay' : 'Thông tin buổi tập',
                          style: TextStyle(
                            color: isPast
                                ? Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.38)
                                : Theme.of(context).colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // --------------------------------------------------
              // NGÀY QUÁ KHỨ
              // --------------------------------------------------

              if (isPast)
                _buildPastDateInfo(
                  isTrained: isTrained,
                )

              // --------------------------------------------------
              // NGÀY HÔM NAY / TƯƠNG LAI
              // --------------------------------------------------

              else
                _buildBookingSection(),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAST DATE
  // ============================================================


  Widget _buildPastDateInfo({required bool isTrained}) {
    final date = selectedDate!;
    final workout = trainedDaysOctober[date.day];

    if (isTrained && workout != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đã hoàn thành buổi tập',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          workout['time']!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          workout['type']!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_busy,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.55),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Không có buổi tập nào trong ngày này.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ============================================================
  // BOOKING SECTION
  // ============================================================

  Widget _buildBookingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --------------------------------------------------------
        // STEP 1 - CHỌN PT
        // --------------------------------------------------------

        Text(
          '1. Chọn huấn luyện viên',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        ...trainers.map(
              (trainer) => _trainerOption(trainer),
        ),

        const SizedBox(height: 22),

        // --------------------------------------------------------
        // STEP 2 - CHỌN SLOT
        // --------------------------------------------------------

        if (selectedTrainer != null) ...[
          Text(
            '2. Chọn khung giờ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: slots.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, index) {
              final slot = slots[index];
              return _slotOption(slot['time']!);
            },
          ),

          const SizedBox(height: 22),

          // ------------------------------------------------------
          // STEP 3 - CONFIRM
          // ------------------------------------------------------

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
              canBook ? _showBookingConfirmation : null,
              icon: const Icon(Icons.check),
              label: const Text(
                'Xác nhận đặt lịch',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                disabledBackgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
                disabledForegroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.38),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // TRAINER OPTION
  // ============================================================

  Widget _trainerOption(Map<String, String> trainer) {
    final trainerName = trainer['name']!;
    final isSelected = selectedTrainer == trainerName;

    return GestureDetector(
      onTap: () => _selectTrainer(trainerName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.12)
              : Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.18)
                    : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trainerName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Huấn luyện viên cá nhân',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.38),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SLOT OPTION
  // ============================================================

  Widget _slotOption(String slot) {
    final isSelected = selectedSlot == slot;
    final isUnavailable = selectedDate != null &&
        _isSlotUnavailable(selectedDate!, slot);

    return GestureDetector(
      onTap: isUnavailable ? null : () => _selectSlot(slot),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isUnavailable
              ? Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.02)
              : isSelected
              ? Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.14)
              : Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnavailable
                ? Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.04)
                : isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time,
              size: 17,
              color: isUnavailable
                  ? Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3)
                  : isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                slot,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isUnavailable
                      ? Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3)
                      : isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY SELECTION
  // ============================================================

  Widget _emptySelection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 38,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.38),
          ),
          SizedBox(height: 12),
          Text(
            'Chọn một ngày trên lịch',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Bạn có thể xem lịch sử hoặc đặt lịch cho hôm nay và các ngày sắp tới.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),

          const SizedBox(height: 12),

          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LEGEND
  // ============================================================

  Widget _legend({
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
