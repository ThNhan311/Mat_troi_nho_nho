import 'api_client.dart';
import 'booking_models.dart';
import 'vietnam_time.dart';

class BookingService {
  final ApiClient api;
  BookingService(this.api);
  Future<List<Trainer>> trainers() async =>
      items(await api.request('GET', '/trainers'), Trainer.fromJson);
  Future<Trainer> trainer(String id) async =>
      Trainer.fromJson(object(await api.request('GET', '/trainers/$id')));
  Future<List<Slot>> slots(String ptId, DateTime from, DateTime to) async =>
      items(
        await api.request(
          'GET',
          '/trainers/$ptId/slots',
          query: queryRange(from, to),
        ),
        Slot.fromJson,
      );
  Future<List<Booking>> bookings(DateTime from, DateTime to) async => items(
    await api.request('GET', '/bookings/me', query: queryRange(from, to)),
    Booking.fromJson,
  );
  Future<Booking> cancel(Booking booking) async => transitioned(
    await api.request('POST', '/bookings/${booking.id}/cancel'),
    booking,
    'CANCELLED',
    actor: 'MEMBER',
  );

  Future<Booking> create(String ptId, String slotId) async {
    final payload = await api.request(
      'POST',
      '/bookings',
      body: {'ptId': ptId, 'slotId': slotId},
      expectedStatus: 201,
    );
    final Booking booking;
    try {
      booking = Booking.fromJson(object(payload));
    } catch (_) {
      throw const ApiError(
        201,
        'INVALID_RESPONSE',
        'Máy chủ đã nhận thao tác nhưng dữ liệu trả về không hợp lệ; hãy tải lại lịch.',
        outcomeUnknown: true,
      );
    }
    if (booking.status != 'CONFIRMED' ||
        booking.ptId != ptId ||
        booking.slotId != slotId) {
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Kết quả đặt lịch không khớp yêu cầu; hãy tải lại lịch.',
        outcomeUnknown: true,
      );
    }
    return booking;
  }
}
