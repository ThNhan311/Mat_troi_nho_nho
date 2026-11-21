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
