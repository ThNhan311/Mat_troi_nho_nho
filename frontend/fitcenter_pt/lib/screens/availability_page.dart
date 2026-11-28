import 'package:flutter/material.dart';

import '../services/booking_state.dart';
import '../services/booking_models.dart';
import '../services/vietnam_time.dart';
import '../widgets/api_status.dart';
import '../widgets/brand_logo.dart';
import '../widgets/month_calendar.dart';
import '../widgets/pull_to_reload.dart';
import '../widgets/start_time_dialog.dart';
import '../widgets/student_info.dart';

/// Orange and green mean what they mean on the member calendar.
const bookedColor = Color(0xFFF57C00);
const trainedColor = Color(0xFF2E9E44);

class AvailabilityPage extends StatefulWidget {
  final BookingState state;

  /// Whether this tab is on screen; the month is only read then.
  final bool active;
  const AvailabilityPage({super.key, required this.state, this.active = true});

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  List<Map<String, dynamic>> get _slots => widget.state.availability;

  DateTime get _today => vietnamDate(DateTime.now().toUtc());
  late DateTime _month = DateTime.utc(_today.year, _today.month);

  /// Null shows every upcoming slot.
  DateTime? _day;

  /// The displayed month, for days outside what the app always loads.
  List<Slot> _monthSlots = [];
  List<Booking> _monthBookings = [];
  bool _monthFailed = false, _wasLoading = false, _started = false;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
    _sync(false);
  }

  @override
  void didUpdateWidget(AvailabilityPage old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_onState);
      widget.state.addListener(_onState);
    }
    if (widget.active && !old.active) _sync(true);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    super.dispose();
  }

  void _onState() => _sync(false);

  /// Reads after the app's own lists, and again after every reload.
  void _sync(bool returned) {
    final state = widget.state;
    final ready = state.loaded && !state.loading && state.alive;
    if (!widget.active) {
      if (state.loading) _started = false;
      _wasLoading = state.loading;
      return;
    }
    if (ready && (!_started || _wasLoading || returned)) {
      _started = true;
      _loadMonth();
    }
    _wasLoading = state.loading;
  }

  Future<void> _loadMonth() async {
    final ticket = ++_ticket;
    final api = widget.state.service.api;
    final epoch = api.sessionEpoch;
    // Midnight in Vietnam is 17:00 UTC of the previous day.
    DateTime start(int offset) => DateTime.utc(
      _month.year,
      _month.month + offset,
    ).subtract(const Duration(hours: 7));
    final range = queryRange(start(0), start(1));
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

    final slots = read('/pt/slots', Slot.fromJson);
    final bookings = read('/pt/bookings', Booking.fromJson);
    final slotRows = await slots, bookingRows = await bookings;
    if (!mounted || ticket != _ticket || epoch != api.sessionEpoch) return;
    setState(() {
      _monthSlots = slotRows;
      _monthBookings = bookingRows;
      _monthFailed = failed;
    });
  }

  /// Inside the loaded window only the app's own list is trusted, so a removed
  /// slot never comes back from the month read.
  bool _outsideWindow(DateTime instant) =>
      instant.isBefore(widget.state.from) || !instant.isBefore(widget.state.to);

  Iterable<Slot> get _calendarSlots => {
    for (final s in _monthSlots)
      if (_outsideWindow(s.startAt)) s.id: s,
    for (final s in widget.state.slots) s.id: s,
  }.values.where((s) => s.status != 'DISABLED');

  Iterable<Booking> get _calendarBookings => {
    for (final b in _monthBookings) b.id: b,
    for (final b in widget.state.bookings) b.id: b,
  }.values;

  bool _on(DateTime instant, DateTime day) => vietnamDate(instant) == day;

  Color get _freeColor => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black;

  /// Dots under a day, in the same order as the legend.
  List<Color> _marks(DateTime day) {
    final now = DateTime.now().toUtc();
    bool has(String status) =>
        _calendarBookings.any((b) => b.status == status && _on(b.startAt, day));
    return [
      if (_calendarSlots.any(
        (s) =>
            s.status == 'AVAILABLE' &&
            s.startAt.isAfter(now) &&
            _on(s.startAt, day),
      ))
        _freeColor,
      if (has('CONFIRMED')) bookedColor,
      if (has('COMPLETED')) trainedColor,
    ];
  }

  void _showMonth(int offset) {
    setState(() {
      _month = DateTime.utc(_month.year, _month.month + offset);
      _day = null;
      _monthSlots = [];
      _monthBookings = [];
      _monthFailed = false;
    });
    _loadMonth();
  }

  List<Map<String, dynamic>> get _shownSlots {
    final day = _day;
    if (day == null) return _slots;
    final rows = _calendarSlots.where((s) => _on(s.startAt, day)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return rows.map(widget.state.slot).toList();
  }

  /// The session that booked a slot, with what is known about the student.
  Map<String, dynamic>? _bookedBy(Slot slot) {
    final booking = _calendarBookings
        .where((b) => b.slotId == slot.id && b.status != 'CANCELLED')
        .firstOrNull;
    return booking == null ? null : widget.state.session(booking);
  }

  String _dayName(DateTime day) => day == _today
      ? 'Hôm nay'
      : 'Ngày ${day.day.toString().padLeft(2, '0')}/'
            '${day.month.toString().padLeft(2, '0')}';
  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
  bool _hasStartedOrPassed(Map<String, dynamic> slot) =>
      !(slot['dto'] as Slot).startAt.isAfter(DateTime.now().toUtc());

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

  /// The team's rule: every session is this long, so only the start is chosen.
  static const _sessionMinutes = 90;

  TimeOfDay? _endOf(TimeOfDay? start) {
    if (start == null) return null;
    // A late session ends after midnight.
    final end = (start.hour * 60 + start.minute + _sessionMinutes) % (24 * 60);
    return TimeOfDay(hour: end ~/ 60, minute: end % 60);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSlotDialog({Map<String, dynamic>? existingSlot}) async {
    await widget.state.act(() async {
      final isEditing = existingSlot != null;

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

      // A new slot starts on the chosen day, unless that day has gone.
      final chosen = _day;
      DateTime selectedDate =
          existingSlot?['date'] as DateTime? ??
          (chosen != null && !chosen.isBefore(_today) ? chosen : _today);

      TimeOfDay? selectedStart;

      if (existingSlot != null) {
        final startParts = (existingSlot['start'] as String).split(':');

        selectedStart = TimeOfDay(
          hour: int.parse(startParts[0]),
          minute: int.parse(startParts[1]),
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
                    final time = selectedStart;
                    if (time != null && !startsLater(selectedDate, time)) {
                      selectedStart = null;
                      validationMessage =
                          'Giờ đã chọn đã qua trong ngày này. '
                          'Hãy chọn lại giờ bắt đầu.';
                    }
                  });
                }
              }

              Future<void> chooseTime() async {
                final pickedTime = await showDialog<TimeOfDay>(
                  useRootNavigator: false,
                  context: dialogContext,
                  builder: (_) =>
                      StartTimeDialog(day: selectedDate, keep: selectedStart),
                );

                if (pickedTime != null) {
                  setDialogState(() {
                    selectedStart = pickedTime;
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
                        borderRadius: BorderRadius.circular(20),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon: Icon(Icons.calendar_month),
                          ),
                          child: Text(_formatDate(selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Giờ bắt đầu'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('slot-start-time'),
                        onPressed: chooseTime,
                        icon: const Icon(Icons.access_time),
                        label: Text(_formatTime(selectedStart)),
                      ),
                      const SizedBox(height: 12),
                      // Worked out from the start, so it is not a button.
                      Text(
                        selectedStart == null
                            ? 'Giờ kết thúc: tự tính sau giờ bắt đầu '
                                  '$_sessionMinutes phút.'
                            : 'Giờ kết thúc: '
                                  '${_formatTime(_endOf(selectedStart))} '
                                  '($_sessionMinutes phút)',
                        key: const Key('slot-end-time'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (validationMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          validationMessage!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
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
                      if (selectedStart == null) {
                        setDialogState(() {
                          validationMessage = 'Vui lòng chọn giờ bắt đầu.';
                        });
                        return;
                      }

                      if (!startsLater(selectedDate, selectedStart!)) {
                        final now = vietnamClock(DateTime.now().toUtc());
                        setDialogState(() {
                          validationMessage =
                              'Giờ ${_formatTime(selectedStart)} đã qua. '
                              'Bây giờ là $now, hãy chọn giờ muộn hơn.';
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

  Future<void> _deleteSlot(Map<String, dynamic> slot) async {
    await widget.state.act(() async {
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
              child: Text(
                'Xóa',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
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
    final day = _day;
    final shown = _shownSlots;
    return Scaffold(
      body: SafeArea(
        child: PullToReload(
          onReload: () => PullToReload.bookings(widget.state),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              ApiStatus(state: widget.state),
              // The logo shares the title's line.
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lịch làm',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  BrandLogo(width: 100),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Theo dõi lịch dạy và mở khung giờ rảnh',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.65),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              MonthCalendar(
                month: _month,
                today: _today,
                selected: day,
                marksOf: _marks,
                legend: [
                  (_freeColor, 'Khung giờ trống'),
                  (bookedColor, 'Đã được đặt'),
                  (trainedColor, 'Đã dạy'),
                ],
                onPrevious: () => _showMonth(-1),
                onNext: () => _showMonth(1),
                // Tapping the chosen day again shows everything.
                onSelect: (date) =>
                    setState(() => _day = date == _day ? null : date),
                note: _monthFailed
                    ? 'Chưa tải đủ trạng thái lịch. Kéo xuống để tải lại.'
                    : null,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('create-slot'),
                onPressed: widget.state.blocked
                    ? null
                    : () => _showSlotDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Tạo khung giờ làm'),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      day == null
                          ? 'Tất cả khung giờ'
                          : '${_dayName(day)} • ${shown.length} khung giờ',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (day != null)
                    TextButton(
                      key: const Key('all-slots'),
                      onPressed: () => setState(() => _day = null),
                      child: const Text('Xem tất cả'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (shown.isNotEmpty)
                for (final slot in shown) _buildSlotCard(context, slot)
              else if (day == null)
                _buildEmptyState(context)
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    '${_dayName(day)} chưa có khung giờ làm.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCard(BuildContext context, Map<String, dynamic> slot) {
    final colors = Theme.of(context).colorScheme;
    final isBooked = slot['booked'] == true;
    final date = slot['date'] as DateTime;
    final isLocked = _hasStartedOrPassed(slot);
    final canManage = !isBooked && !isLocked && !widget.state.blocked;
    final student = isBooked ? _bookedBy(slot['dto'] as Slot) : null;
    // Free is the black of the legend; booked is its orange.
    final tone = isBooked ? bookedColor : _freeColor;

    return Container(
      key: ValueKey('availability-${slot['id']}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: isBooked
            ? Border.all(color: bookedColor.withValues(alpha: 0.35))
            : null,
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
                    _showSlotDialog(existingSlot: slot);
                  } else if (value == 'delete') {
                    _deleteSlot(slot);
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
              color: tone.withValues(alpha: isBooked ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isBooked ? 'Đã được đặt' : 'Chưa được đặt',
              style: TextStyle(
                color: tone,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          if (student != null) ...[
            Divider(height: 24, color: colors.outlineVariant),
            StudentInfo(
              api: widget.state.service.api,
              session: student,
              avatarSize: 56,
            ),
          ],
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
        borderRadius: BorderRadius.circular(22),
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
