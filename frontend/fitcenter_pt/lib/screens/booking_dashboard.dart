import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/booking_models.dart';
import '../services/booking_service.dart';
import '../services/vietnam_time.dart';

class BookingDashboard extends StatefulWidget {
  final BookingService service;
  const BookingDashboard({super.key, required this.service});
  @override
  State<BookingDashboard> createState() => _BookingDashboardState();
}

class _BookingDashboardState extends State<BookingDashboard> {
  late DateTime from = DateTime.now().toUtc().subtract(const Duration(days: 1));
  late DateTime to = from.add(const Duration(days: 32));
  final startInput = TextEditingController();
  List<Slot> slots = [];
  List<Booking> bookings = [];
  String? message, error;
  bool loading = true, sending = false, needsReconciliation = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    startInput.dispose();
    super.dispose();
  }

  Future<void> load({bool manual = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.service.slots(from, to),
        widget.service.bookings(from, to),
      ]);
      if (!mounted) return;
      setState(() {
        slots = results[0] as List<Slot>;
        bookings = results[1] as List<Booking>;
        if (manual) needsReconciliation = false;
      });
    } on ApiError catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Không thể đọc dữ liệu máy chủ; không có dữ liệu demo thay thế.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    if (sending || loading || needsReconciliation) return;
    DateTime start;
    try {
      start = parseVietnamInput(startInput.text.trim());
      if (!start.isAfter(DateTime.now().toUtc())) {
        throw const FormatException('Slot phải ở tương lai.');
      }
    } on FormatException catch (failure) {
      setState(() => error = failure.message);
      return;
    }
    setState(() {
      sending = true;
      message = null;
      error = null;
    });
    try {
      final slot = await widget.service.create(start);
      if (!mounted) return;
      setState(() {
        message =
            'Tạo slot thành công • ${slot.status}\nSlot: ${slot.id}\n${vietnamTime(slot.startAt)} → ${vietnamTime(slot.endAt)}';
        startInput.clear();
      });
      await load();
    } on ApiError catch (failure) {
      if (!mounted) return;
      setState(() {
        error = failure.toString();
        needsReconciliation = failure.outcomeUnknown || failure.status == 401;
      });
      if (failure.status == 409) {
        final conflict = failure.toString();
        await load();
        if (mounted) setState(() => error = conflict);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          needsReconciliation = true;
          error =
              'Chưa thể xác nhận kết quả. Hãy tải lại slot trước khi thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('FitCenter PT • Availability & Sessions'),
      actions: [
        TextButton(
          onPressed: sending ? null : widget.service.api.logout,
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Giờ Việt Nam (UTC+07:00) • dữ liệu từ máy chủ'),
            OutlinedButton(
              key: const Key('refresh'),
              onPressed: loading || sending ? null : () => load(manual: true),
              child: const Text('Tải lại dữ liệu'),
            ),
          ],
        ),
        Text('Khoảng xem: ${vietnamTime(from)} → ${vietnamTime(to)}'),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!, key: const Key('api-error')),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(message!, key: const Key('success')),
          ),
        if (needsReconciliation)
          const Text(
            'Kết quả gửi chưa rõ. Tải lại dữ liệu và kiểm tra slot trước thao tác mới.',
          ),
        const SizedBox(height: 20),
        Text(
          'Tạo slot 90 phút',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        TextField(
          key: const Key('slot-start'),
          controller: startInput,
          enabled: !sending && !loading,
          decoration: const InputDecoration(
            labelText: 'Bắt đầu (giờ Việt Nam)',
            hintText: 'YYYY-MM-DD HH:mm',
          ),
        ),
        const Text(
          'Kết thúc = bắt đầu + 90 phút. Không gửi ptId; máy chủ xác định PT đăng nhập.',
        ),
        FilledButton(
          key: const Key('create-slot'),
          onPressed: sending || loading || needsReconciliation ? null : create,
          child: Text(sending ? 'Đang tạo…' : 'Tạo slot'),
        ),
        const SizedBox(height: 24),
        Text(
          'Availability của tôi',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (!loading && slots.isEmpty)
          const Text('Chưa có slot trong khoảng xem.'),
        ...slots.map(
          (slot) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Slot: ${slot.id}\n${vietnamTime(slot.startAt)} → ${vietnamTime(slot.endAt)}\n${slot.status}',
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Lịch session của tôi',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (!loading && bookings.isEmpty)
          const Text('Chưa có booking trong khoảng xem.'),
        ...bookings.map(
          (booking) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Booking: ${booking.id}\nMember: ${shortId(booking.memberId)}\n${vietnamTime(booking.startAt)} → ${vietnamTime(booking.endAt)}\n${booking.status}',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
