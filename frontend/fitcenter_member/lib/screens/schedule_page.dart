import 'package:flutter/material.dart';

import '../widgets/day_summary_card.dart';
import '../widgets/detail_row.dart';
import '../services/booking_models.dart';
import '../services/booking_state.dart';
import '../services/vietnam_time.dart';
import '../widgets/api_status.dart';
import '../widgets/pull_to_reload.dart';
import '../widgets/brand_logo.dart';
import '../widgets/trainer_photo.dart';
import 'trainer_detail_page.dart';

class SchedulePage extends StatefulWidget {
  final BookingState state;
  const SchedulePage({super.key, required this.state});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  // ============================================================
  // THÁNG HIỂN THỊ
  // ============================================================

  final _scroll = ScrollController();

  /// Days on which at least one PT has a free slot; null while unknown.
  Set<DateTime>? _openDays;

  /// The same answer for each trainer; null while unknown.
  Map<String, Set<DateTime>>? _trainerDays;
  Map<String, List<Slot>> _trainerSlots = {};
  (DateTime, DateTime)? _openRange;
  bool _wasLoading = false;
  bool _started = false;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
    _onState();
  }

  @override
  void didUpdateWidget(SchedulePage old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_onState);
      widget.state.addListener(_onState);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    _scroll.dispose();
    super.dispose();
  }

  /// Checks again whenever the bookings finish loading.
  void _onState() {
    final ready = state.loaded && !state.loading && state.alive;
    if (ready && (!_started || _wasLoading)) {
      _started = true;
      _loadOpenDays();
      _loadMarks();
    }
    _wasLoading = state.loading;
  }

  Future<void> _loadOpenDays() async {
    final ticket = ++_ticket;
    final api = state.service.api;
    final epoch = api.sessionEpoch;
    final range = (state.from, state.to);
    // Days from another month must not be judged by the old answer.
    if (range != _openRange) {
      _openDays = null;
      _trainerDays = null;
      _trainerSlots = {};
    }
    bool current() => mounted && ticket == _ticket && epoch == api.sessionEpoch;
    final ids = [for (final trainer in state.trainers) trainer.id];
    try {
      final lists = await Future.wait([
        for (final id in ids)
          api.peek(
            '/trainers/$id/slots',
            query: queryRange(range.$1, range.$2),
          ),
      ]);
      final byTrainer = {
        for (var i = 0; i < lists.length; i++)
          ids[i]: {
            for (final slot in items(lists[i], Slot.fromJson))
              if (slot.status == 'AVAILABLE') vietnamDate(slot.startAt),
          },
      };
      final freeSlots = {
        for (var i = 0; i < lists.length; i++)
          ids[i]:
              items(
                  lists[i],
                  Slot.fromJson,
                ).where((slot) => slot.status == 'AVAILABLE').toList()
                ..sort((a, b) => a.startAt.compareTo(b.startAt)),
      };
      if (current()) {
        setState(() {
          _trainerSlots = freeSlots;
          _trainerDays = byTrainer;
          _openDays = {for (final days in byTrainer.values) ...days};
          _openRange = range;
        });
      }
    } catch (_) {
      // Unknown is not "no slots": the page then keeps the booking steps.
      if (current()) {
        setState(() {
          _openDays = null;
          _trainerDays = null;
          _trainerSlots = {};
        });
      }
    }
  }

  /// True only when it is certain that nobody can be booked on this day.
  bool _hasNoSlots(DateTime date) {
    final open = _openDays;
    return !state.loading &&
        open != null &&
        !_isPastDate(date) &&
        !open.contains(_dateOnly(date));
  }

  String _noSlotsText(DateTime date) {
    final name = _isToday(date)
        ? 'Hôm nay'
        : 'Ngày ${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}';
    return '$name không có khung giờ khả dụng.';
  }

  BookingState get state => widget.state;
  DateTime displayedMonth = vietnamDate(DateTime.now().toUtc());
  DateTime? get selectedDate => state.selectedDay;
  String? get selectedTrainer => state.trainer?.fullName;
  String? get selectedSlot => state.slotChoices
      .where((s) => s['id'] == state.slotId)
      .firstOrNull?['time'];
  List<Map<String, String>> get trainers => state.trainerChoices;
  List<Map<String, String>> get slots => state.slotChoices;
  DateTime _dateOnly(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  DateTime get today => vietnamDate(DateTime.now().toUtc());

  bool _isPastDate(DateTime date) {
    return _dateOnly(date).isBefore(today);
  }

  bool _isToday(DateTime date) {
    return _dateOnly(date) == today;
  }

  bool _isSlotUnavailable(DateTime date, String time) =>
      state.blocked || !slots.any((s) => s['time'] == time);
  Set<DateTime> _checkinDays = {};
  List<DateTime> _checkinTimes = [];
  bool _marksReady = false;
  List<Booking> _monthBookings = [];
  bool _marksFailed = false;
  int _markTicket = 0;

  /// The latest copy of each booking: the page's own list wins over the month.
  Iterable<Booking> get _calendarBookings => {
    for (final b in _monthBookings) b.id: b,
    for (final b in state.bookings) b.id: b,
  }.values;

  bool _hasBooking(DateTime date, String status) => _calendarBookings.any(
    (b) => b.status == status && vietnamDate(b.startAt) == _dateOnly(date),
  );

  bool _isTrained(DateTime date) => _hasBooking(date, 'COMPLETED');

  /// Dots under a day, in the same order as the legend.
  List<Color> _marks(DateTime date) => [
    // Training with a PT means the member was at the gym that day.
    if (_checkinDays.contains(_dateOnly(date)) || _isTrained(date))
      _checkinColor,
    if (_hasBooking(date, 'CONFIRMED')) _bookedColor,
    if (_isTrained(date)) _trainedColor,
  ];

  Color get _checkinColor => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black;
  static const _bookedColor = Color(0xFFF57C00);
  static const _trainedColor = Color(0xFF2E9E44);

  Future<void> _loadMarks() async {
    final ticket = ++_markTicket;
    final api = state.service.api;
    final epoch = api.sessionEpoch;
    final month = displayedMonth;
    // Midnight in Vietnam is 17:00 UTC of the previous day.
    DateTime start(int offset) => DateTime.utc(
      month.year,
      month.month + offset,
    ).subtract(const Duration(hours: 7));
    final range = queryRange(start(0), start(1));
    bool current() =>
        mounted && ticket == _markTicket && epoch == api.sessionEpoch;
    var failed = false;
    Future<List<T>> read<T>(
      String path,
      T Function(Map<String, dynamic>) parse,
    ) async {
      try {
        return items(await api.peek(path, query: range), parse);
      } catch (_) {
        failed = true;
        return <T>[];
      }
    }

    final checkins = read(
      '/attendance/me',
      (row) => instant(row, 'checkedInAt'),
    );
    final bookings = read('/bookings/me', Booking.fromJson);
    final times = await checkins;
    final rows = await bookings;
    if (!current()) return;
    setState(() {
      _checkinTimes = times;
      _checkinDays = {for (final at in times) vietnamDate(at)};
      _marksReady = true;
      _monthBookings = rows;
      _marksFailed = failed;
    });
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
    if (state.blocked) return;
    setState(() {
      displayedMonth = DateTime.utc(
        displayedMonth.year,
        displayedMonth.month - 1,
      );
      _marksReady = false;
    });
    state.month(displayedMonth);
  }

  void _nextMonth() {
    if (state.blocked) return;
    setState(() {
      displayedMonth = DateTime.utc(
        displayedMonth.year,
        displayedMonth.month + 1,
      );
      _marksReady = false;
    });
    state.month(displayedMonth);
  }

  void _selectDate(DateTime date) => state.selectDay(date);
  void _selectTrainer(String id) => state.selectTrainer(id);
  void _selectSlot(String id) => state.selectSlot(id);
  bool get canBook =>
      !state.blocked &&
      selectedDate != null &&
      state.trainerId != null &&
      state.slotId != null;

  Future<void> _showBookingConfirmation() async {
    if (!canBook) {
      _showMessage('Vui lòng chọn đầy đủ PT và khung giờ.');
      return;
    }

    await state.act(() async {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
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

                DetailRow('Huấn luyện viên', selectedTrainer!),

                DetailRow('Ngày', _formatDate(selectedDate!)),

                DetailRow('Khung giờ', selectedSlot!),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary
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
                            color: Theme.of(context).colorScheme.onSurface
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
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
      if (confirmed == true && mounted && state.alive)
        await state.createSelected();
    });
    if (mounted && _scroll.hasClients) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
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
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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

    return SafeArea(
      child: PullToReload(
        onReload: () => PullToReload.bookings(state),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),

          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            ApiStatus(state: state),
            // ======================================================
            // HEADER
            // ======================================================

            // The logo shares the title's line.
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lịch tập',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const BrandLogo(width: 100),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Theo dõi lịch tập và đặt lịch với PT',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.65),
                fontSize: 14,
              ),
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
                                color: Theme.of(context).colorScheme.onSurface
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
                      final dayNumber = index - (firstWeekday - 1) + 1;

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
                      final isSelected =
                          selectedDate != null &&
                          _dateOnly(selectedDate!) == _dateOnly(date);
                      final marks = _marks(date);

                      return GestureDetector(
                        key: ValueKey(
                          'day-${date.year}-${date.month}-${date.day}',
                        ),
                        onTap: state.blocked ? null : () => _selectDate(date),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : isToday
                                ? Theme.of(context).colorScheme.primary
                                      .withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday && !isSelected
                                ? Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNumber',
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : isPast
                                      ? Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.3)
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: isToday || isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),

                              const SizedBox(height: 4),

                              SizedBox(
                                height: 8,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (final mark in marks)
                                      Container(
                                        width: isSelected ? 8 : 6,
                                        height: isSelected ? 8 : 6,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: mark,
                                          shape: BoxShape.circle,
                                          // A light ring keeps dots visible
                                          // on the selected day.
                                          border: isSelected
                                              ? Border.all(color: Colors.white)
                                              : null,
                                        ),
                                      ),
                                  ],
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
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _legend(color: _checkinColor, text: 'Đã check-in'),
                      _legend(color: _bookedColor, text: 'Đã đặt trước PT'),
                      _legend(color: _trainedColor, text: 'Đã tập với PT'),
                    ],
                  ),
                  if (_marksFailed) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Chưa tải đủ trạng thái lịch. Kéo xuống để tải lại.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ======================================================
            // SELECTED DATE
            // ======================================================
            if (selectedDate == null)
              _emptySelection()
            else ...[
              _daySummary(selectedDate!),
              if (_hasNoSlots(selectedDate!)) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    _noSlotsText(selectedDate!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ] else if (!_isPastDate(selectedDate!)) ...[
                const SizedBox(height: 12),
                _buildSelectedDateSection(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SELECTED DATE SECTION
  // ============================================================

  Widget _buildSelectedDateSection() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
    ),
    child: _buildBookingSection(),
  );

  /// Check-ins and PT sessions of one day, from what the server returned.
  List<DayEntry> _entriesOf(DateTime date) {
    final day = _dateOnly(date);
    final now = DateTime.now().toUtc();
    final sessions = _calendarBookings
        .where((b) => vietnamDate(b.startAt) == day)
        .toList();
    final scans = _checkinTimes.where((at) => vietnamDate(at) == day).toList();
    return [
      for (final at in scans)
        DayEntry(
          at: at,
          color: _checkinColor,
          title: 'Check-in lúc ${vietnamClock(at)}',
        ),
      // Training with a PT counts as being there, even without a scan.
      if (scans.isEmpty && _isTrained(date))
        DayEntry(
          at: sessions.where((b) => b.status == 'COMPLETED').first.startAt,
          color: _checkinColor,
          title: 'Có check-in',
          detail: 'Tính theo buổi tập với PT, không có giờ quét.',
        ),
      for (final b in sessions) _sessionEntry(b, now),
    ];
  }

  DayEntry _sessionEntry(Booking b, DateTime now) {
    final trainer = state.trainerName(b.ptId);
    final hours = '${vietnamClock(b.startAt)} - ${vietnamClock(b.endAt)}';
    switch (b.status) {
      case 'COMPLETED':
        return DayEntry(
          at: b.startAt,
          color: _trainedColor,
          title: 'Đã tập với $trainer',
          detail: hours,
        );
      case 'CANCELLED':
        final who = switch (b.cancelledBy) {
          'MEMBER' => 'Bạn đã hủy',
          'PT' => 'PT đã hủy',
          _ => 'Đã hủy',
        };
        final reason = b.cancelReason?.trim() ?? '';
        return DayEntry(
          at: b.startAt,
          color: Theme.of(context).colorScheme.error,
          title: 'Buổi với $trainer đã hủy',
          detail: '$hours\n$who${reason.isEmpty ? '' : ': $reason'}',
        );
      default:
        return DayEntry(
          at: b.startAt,
          color: _bookedColor,
          title: 'Đã đặt trước với $trainer',
          detail: b.endAt.isBefore(now)
              ? '$hours\nPT chưa xác nhận hoàn tất.'
              : hours,
        );
    }
  }

  Widget _daySummary(DateTime date) {
    final complete = _marksReady && !_marksFailed;
    return DaySummaryCard(
      key: const Key('day-summary'),
      date: _formatDate(date),
      badge: _isToday(date) ? 'Hôm nay' : null,
      entries: _entriesOf(date),
      // "Nothing happened" is only said when the whole month was read.
      emptyText: !complete
          ? null
          : _isPastDate(date)
          ? 'Ngày này bạn không check-in và không có buổi PT.'
          : _isToday(date)
          ? 'Hôm nay bạn chưa check-in và chưa có buổi PT.'
          : 'Ngày này bạn chưa có buổi PT nào.',
      note: _marksFailed
          ? 'Chưa tải đủ dữ liệu của ngày này. Kéo xuống để tải lại.'
          : _marksReady
          ? null
          : 'Đang tải...',
    );
  }

  void _openProfile(String id) => state.act(() async {
    final detail = await state.service.trainer(id);
    if (!mounted || !state.alive) return;
    // Not awaited: the schedule must stay usable while the profile is open.
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (route) => TrainerDetailPage(
          trainerName: detail.fullName,
          photo: TrainerPhoto(
            api: state.service.api,
            id: detail.id,
            name: detail.fullName,
            size: TrainerDetailPage.photoSize,
          ),
          bio: detail.bio,
          specialization: detail.specialization,
          experience: detail.experienceSummary,
          phone: detail.phone,
          gender: detail.gender,
          slots: _trainerSlots[detail.id],
          onShowMessage: _showMessage,
          onBookAppointment: () {
            Navigator.pop(route);
            _selectTrainer(detail.id);
          },
        ),
      ),
    );
  });

  /// Trainers free on the chosen day. Everyone stays while that is unknown.
  List<Map<String, String>> get _trainersThatDay {
    final days = _trainerDays;
    final date = selectedDate;
    if (days == null || date == null) return trainers;
    return [
      for (final trainer in trainers)
        if (days[trainer['id']]?.contains(_dateOnly(date)) ?? true) trainer,
    ];
  }

  Widget _buildBookingSection() {
    final offered = _trainersThatDay;
    // A trainer chosen for another day must not keep the next steps open.
    final hasChoice =
        selectedTrainer != null &&
        offered.any((trainer) => trainer['id'] == state.trainerId);
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

        ...offered.map((trainer) => _trainerOption(trainer)),

        const SizedBox(height: 22),

        // --------------------------------------------------------
        // STEP 2 - CHỌN SLOT
        // --------------------------------------------------------
        if (hasChoice) ...[
          Text(
            '2. Chọn khung giờ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          if (!state.loading && slots.isEmpty)
            const Text('PT này chưa có khung giờ trống trong ngày đã chọn.'),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: slots.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, index) {
              final slot = slots[index];
              return _slotOption(slot);
            },
          ),

          const SizedBox(height: 22),

          // ------------------------------------------------------
          // STEP 3 - CONFIRM
          // ------------------------------------------------------
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canBook ? _showBookingConfirmation : null,
              icon: const Icon(Icons.check),
              label: const Text(
                'Xác nhận đặt lịch',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                disabledBackgroundColor: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.08),
                disabledForegroundColor: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.38),
                padding: const EdgeInsets.symmetric(vertical: 16),
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
    final isSelected = state.trainerId == trainer['id'];

    return GestureDetector(
      key: ValueKey('choose-trainer-${trainer['id']}'),
      onTap: state.blocked ? null : () => _selectTrainer(trainer['id']!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface
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
                    ? Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.18)
                    : Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface
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
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Looking at the profile does not choose the trainer.
                  OutlinedButton(
                    key: ValueKey('trainer-profile-${trainer['id']}'),
                    onPressed: state.blocked
                        ? null
                        : () => _openProfile(trainer['id']!),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Xem hồ sơ'),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface
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

  Widget _slotOption(Map<String, String> data) {
    final slot = data['time']!;
    final id = data['id']!;
    final isSelected = state.slotId == id;
    final isUnavailable =
        selectedDate != null && _isSlotUnavailable(selectedDate!, slot);

    return GestureDetector(
      key: ValueKey('slot-$id'),
      onTap: isUnavailable ? null : () => _selectSlot(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isUnavailable
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.02)
              : isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isUnavailable
                ? Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.04)
                : isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface
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
                  ? Theme.of(context).colorScheme.onSurface
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
                      ? Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.3)
                      : isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 38,
            color: Theme.of(context).colorScheme.onSurface
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
              color: Theme.of(context).colorScheme.onSurface
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

  // ============================================================
  // LEGEND
  // ============================================================

  Widget _legend({required Color color, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
