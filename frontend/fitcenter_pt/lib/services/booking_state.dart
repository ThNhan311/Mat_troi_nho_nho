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

  void clearSelection() {}
  Future<void> refresh({bool manual = false}) async {
    if (!alive) return;
    final version = ++_readVersion;
    loading = true;
    error = null;
    changed();
    try {
      final result = await Future.wait<Object>([
        service.slots(from, to),
        service.bookings(from, to),
      ]);
      if (!alive || version != _readVersion) return;
      slots = result[0] as List<Slot>;
      bookings = result[1] as List<Booking>;
      loaded = true;
      if (manual) needsReconciliation = false;
    } on ApiError catch (e) {
      if (alive && version == _readVersion) error = e.toString();
    } catch (_) {
      if (alive && version == _readVersion)
        error = 'Không thể tải dữ liệu. Vui lòng thử lại.';
    } finally {
      if (alive && version == _readVersion) {
        loading = false;
        changed();
      }
    }
  }

  Map<String, dynamic> session(Booking b) => {
    'id': b.id,
    'memberName': 'Member ${shortId(b.memberId)}',
    'date': vietnamDate(b.startAt),
    'start': vietnamClock(b.startAt),
    'end': vietnamClock(b.endAt),
    'status': b.status,
    'dto': b,
    if (b.cancelReason != null) 'cancellationReason': b.cancelReason,
    if (b.cancelledAt != null) 'cancelledAt': vietnamTime(b.cancelledAt!),
    if (b.cancelledBy != null) 'cancelledBy': b.cancelledBy,
    if (b.completedAt != null) 'completedAt': vietnamTime(b.completedAt!),
  };
  List<Map<String, dynamic>> get sessions => bookings.map(session).toList();
  Map<String, dynamic> slot(Slot s) => {
    'id': s.id,
    'date': vietnamDate(s.startAt),
    'start': vietnamClock(s.startAt),
    'end': vietnamClock(s.endAt),
    'booked': s.status == 'BOOKED',
    'status': s.status,
    'dto': s,
  };
  List<Map<String, dynamic>> get availability =>
      slots.where((s) => s.status != 'DISABLED').map(slot).toList();
  Future<void> saveSlot(DateTime start, {Slot? previous}) async {
    final next = previous == null
        ? await service.create(start)
        : await service.edit(previous, start);
    if (!alive) return;
    slots = [...slots.where((s) => s.id != previous?.id), next];
    await accepted(
      '${previous == null ? "Đã tạo khung giờ làm." : "Đã cập nhật khung giờ."}\nMã khung giờ: ${next.id}',
    );
  }

  Future<void> remove(Slot slot) async {
    await service.remove(slot);
    if (alive) await accepted('Đã loại khung giờ khỏi lịch làm.');
  }

  Future<void> transition(Booking previous, {String? reason}) async {
    final next = reason == null
        ? await service.complete(previous)
        : await service.cancel(previous, reason);
    if (!alive) return;
    bookings = bookings.map((b) => b.id == next.id ? next : b).toList();
    await accepted(
      reason == null ? 'Đã hoàn tất buổi tập.' : 'Đã hủy buổi tập.',
    );
  }
}
