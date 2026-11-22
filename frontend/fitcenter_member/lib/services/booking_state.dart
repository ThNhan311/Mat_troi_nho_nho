import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'booking_models.dart';
import 'booking_service.dart';
import 'vietnam_time.dart';

/// One authenticated navigation tree owns one instance. No result survives its session.
class BookingState extends ChangeNotifier {
  final BookingService service;
  late final int epoch = service.api.sessionEpoch;
  bool _disposed = false;
  bool loading = false,
      busy = false,
      needsReconciliation = false,
      loaded = false;
  String? error, message;
  int _readVersion = 0;
  List<Booking> bookings = [];
  List<Slot> slots = [];
  DateTime from = DateTime.now().toUtc().subtract(const Duration(days: 1));
  DateTime to = DateTime.now().toUtc().add(const Duration(days: 31));
  BookingState(this.service);
  bool get alive => !_disposed && service.api.sessionEpoch == epoch;
  bool get blocked => loading || busy || needsReconciliation || !alive;
  void changed() {
    if (alive) notifyListeners();
  }

  Future<void> act(Future<void> Function() action) async {
    if (blocked) return;
    busy = true;
    error = null;
    message = null;
    changed();
    try {
      await action();
    } on ApiError catch (e) {
      if (!alive) return;
      error = e.toString();
      needsReconciliation = e.outcomeUnknown || e.status == 401;
      clearSelection();
      if (e.status == 409 || e.status == 404) {
        await refresh();
        if (alive) error = e.toString();
      }
    } catch (_) {
      if (alive) {
        error = 'Chưa rõ kết quả. Hãy tải lại dữ liệu trước khi thử lại.';
        needsReconciliation = true;
        clearSelection();
      }
    } finally {
      if (alive) {
        busy = false;
        changed();
      }
    }
  }

  Future<void> accepted(String text) async {
    if (!alive) return;
    message = text;
    changed();
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _readVersion++;
    super.dispose();
  }

  List<Trainer> trainers = [];
  String? trainerId, slotId;
  DateTime? selectedDay;
  Trainer? get trainer => trainers.where((t) => t.id == trainerId).firstOrNull;
  void clearSelection() {
    slotId = null;
  }

  Future<void> refresh({bool manual = false}) async {
    if (!alive) return;
    final version = ++_readVersion;
    loading = true;
    error = null;
    changed();
    final requestedTrainer = trainerId;
    try {
      final results = await Future.wait<Object>([
        service.trainers(),
        service.bookings(from, to),
        if (requestedTrainer != null) service.slots(requestedTrainer, from, to),
      ]);
      if (!alive || version != _readVersion) return;
      trainers = results[0] as List<Trainer>;
      bookings = results[1] as List<Booking>;
      slots = results.length > 2 ? results[2] as List<Slot> : [];
      if (!trainers.any((t) => t.id == trainerId)) {
        trainerId = null;
        slots = [];
      }
      if (!slots.any((s) => s.id == slotId && s.status == 'AVAILABLE'))
        slotId = null;
      loaded = true;
      if (manual) needsReconciliation = false;
    } on ApiError catch (e) {
      if (alive && version == _readVersion) {
        error = e.toString();
        slots = [];
        clearSelection();
      }
    } catch (_) {
      if (alive && version == _readVersion) {
        error = 'Không thể tải dữ liệu. Vui lòng thử lại.';
        slots = [];
        clearSelection();
      }
    } finally {
      if (alive && version == _readVersion) {
        loading = false;
        changed();
      }
    }
  }

  Future<void> selectTrainer(String id) async {
    if (blocked) return;
    trainerId = id;
    slotId = null;
    slots = [];
    message = null;
    await refresh();
  }

  void selectDay(DateTime day) {
    if (blocked) return;
    selectedDay = day;
    slotId = null;
    changed();
  }

  void selectSlot(String id) {
    if (blocked) return;
    slotId = id;
    changed();
  }

  Future<void> month(DateTime month) async {
    if (blocked) return;
    final first = DateTime.utc(
      month.year,
      month.month,
    ).subtract(const Duration(hours: 7));
    final next = DateTime.utc(
      month.year,
      month.month + 1,
    ).subtract(const Duration(hours: 7));
    // Include the calendar month as well as the original rolling view.
    final now = DateTime.now().toUtc();
    from = first.isBefore(now.subtract(const Duration(days: 1)))
        ? first
        : now.subtract(const Duration(days: 1));
    to = next.isAfter(now.add(const Duration(days: 31)))
        ? next
        : now.add(const Duration(days: 31));
    selectedDay = null;
    clearSelection();
    await refresh();
  }

  List<Slot> get daySlots => slots
      .where(
        (s) =>
            s.status == 'AVAILABLE' &&
            (selectedDay == null || sameVietnamDay(s.startAt, selectedDay!)),
      )
      .toList();
  List<Map<String, String>> get trainerChoices =>
      trainers.map((t) => {'id': t.id, 'name': t.fullName}).toList();
  List<Map<String, String>> get slotChoices => daySlots
      .map(
        (s) => {
          'id': s.id,
          'time': '${vietnamClock(s.startAt)} - ${vietnamClock(s.endAt)}',
        },
      )
      .toList();
  String trainerName(String id) =>
      trainers.where((t) => t.id == id).firstOrNull?.fullName ??
      'PT ${shortId(id)}';
  List<Map<String, String>> get history => bookings
      .map(
        (b) => {
          'id': b.id,
          'trainer': trainerName(b.ptId),
          'date': vietnamDateText(b.startAt),
          'time':
              '${vietnamClock(b.startAt)} - ${vietnamClock(b.endAt)} (giờ Việt Nam)',
          'status': b.status,
          if (b.cancelReason != null) 'reason': b.cancelReason!,
        },
      )
      .toList();
  Future<void> createSelected() async {
    final pt = trainerId, slot = slotId;
    if (pt == null || slot == null) return;
    final booking = await service.create(pt, slot);
    if (!alive) return;
    bookings = [...bookings, booking];
    clearSelection();
    await accepted(
      'Đặt lịch thành công • Đã xác nhận\nMã đặt lịch: ${booking.id}',
    );
  }

  Future<void> cancel(String id) async {
    final previous = bookings.firstWhere((b) => b.id == id);
    final next = await service.cancel(previous);
    if (!alive) return;
    bookings = bookings.map((b) => b.id == next.id ? next : b).toList();
    clearSelection();
    await accepted('Đã hủy lịch tập.\nMã đặt lịch: ${next.id}');
  }
}
