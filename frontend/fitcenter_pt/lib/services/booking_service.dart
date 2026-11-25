import 'api_client.dart';
import 'booking_models.dart';
import 'vietnam_time.dart';

class BookingService {
  final ApiClient api;
  BookingService(this.api);
  Future<List<Slot>> slots(DateTime from, DateTime to) async => items(
    await api.request('GET', '/pt/slots', query: queryRange(from, to)),
    Slot.fromJson,
  );
  Future<List<Booking>> bookings(DateTime from, DateTime to) async => items(
    await api.request('GET', '/pt/bookings', query: queryRange(from, to)),
    Booking.fromJson,
  );
  Future<Slot> edit(Slot previous, DateTime start) async {
    final end = start.add(const Duration(minutes: 90));
    final payload = await api.request(
      'PATCH',
      '/pt/availability/${previous.id}',
      body: {
        'startAt': start.toUtc().toIso8601String(),
        'endAt': end.toUtc().toIso8601String(),
      },
    );
    try {
      final next = Slot.fromJson(object(payload));
      if (next.ptId != previous.ptId ||
          next.status != 'AVAILABLE' ||
          next.startAt != start.toUtc() ||
          next.endAt != end.toUtc())
        throw const FormatException();
      return next;
    } catch (_) {
      throw const ApiError(
        200,
        'INVALID_RESPONSE',
        'Chưa xác nhận được slot thay thế. Tải lại danh sách.',
        outcomeUnknown: true,
      );
    }
  }

  Future<void> remove(Slot slot) async {
    await api.request(
      'DELETE',
      '/pt/availability/${slot.id}',
      expectedStatus: 204,
    );
  }

  Future<Booking> cancel(Booking booking, String reason) async {
    if (reason.trim().isEmpty)
      throw const ApiError(400, 'ERR_VALIDATION', 'Cần nhập lý do hủy.');
    final next = transitioned(
      await api.request(
        'POST',
        '/pt/bookings/${booking.id}/cancel',
        body: {'reason': reason},
      ),
      booking,
      'CANCELLED',
      actor: 'PT',
    );
    if (next.cancelReason != reason)
      throw const ApiError(
        200,
        'INVALID_RESPONSE',
        'Lý do trả về không khớp. Tải lại lịch.',
        outcomeUnknown: true,
      );
    return next;
  }

  Future<Booking> complete(Booking booking) async => transitioned(
    await api.request('POST', '/pt/bookings/${booking.id}/complete'),
    booking,
    'COMPLETED',
  );
  Future<ServiceEligibility> eligibility(Booking booking) async =>
      ServiceEligibility.fromJson(
        object(
          await api.request(
            'GET',
            '/pt/bookings/${booking.id}/service-eligibility',
          ),
        ),
      );

  Future<Slot> create(DateTime start) async {
    final end = start.add(const Duration(minutes: 90));
    final payload = await api.request(
      'POST',
      '/pt/availability',
      body: {
        'startAt': start.toUtc().toIso8601String(),
        'endAt': end.toUtc().toIso8601String(),
      },
      expectedStatus: 201,
    );
    final Slot slot;
    try {
      slot = Slot.fromJson(object(payload));
    } catch (_) {
      throw const ApiError(
        201,
        'INVALID_RESPONSE',
        'Máy chủ đã nhận thao tác nhưng dữ liệu trả về không hợp lệ; hãy tải lại slot.',
        outcomeUnknown: true,
      );
    }
    if (slot.status != 'AVAILABLE' ||
        slot.startAt != start.toUtc() ||
        slot.endAt != end.toUtc()) {
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Kết quả tạo slot không khớp yêu cầu; hãy tải lại danh sách.',
        outcomeUnknown: true,
      );
    }
    return slot;
  }
}
