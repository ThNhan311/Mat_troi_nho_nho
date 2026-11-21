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
  List<Trainer> trainers = [];
  List<Slot> slots = [];
  List<Booking> bookings = [];
  Trainer? selectedTrainer;
  String? selectedSlot;
  String? message, error;
  bool loading = true, sending = false, needsReconciliation = false;
  int loadVersion = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool manual = false}) async {
    final version = ++loadVersion;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.service.trainers(),
        widget.service.bookings(from, to),
      ]);
      if (!mounted || version != loadVersion) return;
      final fetched = results[0] as List<Trainer>;
      final id = selectedTrainer?.id;
      final matches = fetched.where((trainer) => trainer.id == id);
      Trainer? detail;
      List<Slot> fetchedSlots = [];
      if (matches.isNotEmpty) {
        detail = await widget.service.trainer(id!);
        fetchedSlots = await widget.service.slots(id, from, to);
      }
      if (!mounted || version != loadVersion) return;
      setState(() {
        trainers = fetched;
        bookings = results[1] as List<Booking>;
        selectedTrainer = detail;
        slots = fetchedSlots;
        if (!slots.any(
          (slot) => slot.id == selectedSlot && slot.status == 'AVAILABLE',
        )) {
          selectedSlot = null;
        }
        if (manual) needsReconciliation = false;
      });
    } on ApiError catch (failure) {
      if (mounted && version == loadVersion) {
        setState(() {
          error = failure.toString();
          slots = [];
          selectedSlot = null;
        });
      }
    } catch (_) {
      if (mounted && version == loadVersion) {
        setState(
          () => error =
              'Không thể đọc dữ liệu máy chủ; không có dữ liệu demo thay thế.',
        );
      }
    } finally {
      if (mounted && version == loadVersion) setState(() => loading = false);
    }
  }

  Future<void> selectTrainer(Trainer trainer) async {
    if (loading || sending) return;
    setState(() {
      selectedTrainer = trainer;
      selectedSlot = null;
      slots = [];
      message = null;
    });
    await load();
  }

  Future<void> book() async {
    final trainer = selectedTrainer;
    final slot = selectedSlot;
    if (sending ||
        loading ||
        needsReconciliation ||
        trainer == null ||
        slot == null) {
      return;
    }
    setState(() {
      sending = true;
      message = null;
      error = null;
    });
    try {
      final booking = await widget.service.create(trainer.id, slot);
      if (!mounted) return;
      setState(() {
        selectedSlot = null;
        message =
            'Đặt lịch thành công • CONFIRMED\nBooking: ${booking.id}\n${vietnamTime(booking.startAt)} → ${vietnamTime(booking.endAt)}';
      });
      await load();
    } on ApiError catch (failure) {
      if (!mounted) return;
      setState(() {
        selectedSlot = null;
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
          selectedSlot = null;
          error = 'Chưa thể xác nhận kết quả. Hãy tải lại lịch để đối chiếu, không gửi lại ngay.';
        });
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('FitCenter Member • Booking'),
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
            'Kết quả gửi chưa được đối chiếu. Tải lại dữ liệu và kiểm tra lịch trước thao tác mới.',
          ),
        const SizedBox(height: 20),
        Text(
          'Huấn luyện viên',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (!loading && trainers.isEmpty)
          const Text('Không có huấn luyện viên để hiển thị.'),
        ...trainers.map(
          (trainer) => Card(
            child: ListTile(
              key: ValueKey('trainer-${trainer.id}'),
              selected: selectedTrainer?.id == trainer.id,
              title: Text(trainer.fullName),
              subtitle: Text(
                trainer.specialization ?? 'Chưa có mô tả chuyên môn',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: loading || sending ? null : () => selectTrainer(trainer),
            ),
          ),
        ),
        if (selectedTrainer != null) ...[
          const SizedBox(height: 12),
          Text(
            'Hồ sơ PT • ${selectedTrainer!.fullName}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (selectedTrainer!.bio != null) Text(selectedTrainer!.bio!),
          if (selectedTrainer!.experienceSummary != null)
            Text(selectedTrainer!.experienceSummary!),
          const SizedBox(height: 12),
          const Text('Slot available'),
          if (!loading && slots.isEmpty)
            const Text('Không có slot khả dụng trong khoảng xem.'),
          ...slots
              .where((slot) => slot.status == 'AVAILABLE')
              .map(
                (slot) => Card(
                  child: ListTile(
                    key: ValueKey('slot-${slot.id}'),
                    title: Text(vietnamTime(slot.startAt)),
                    subtitle: Text(
                      '${vietnamTime(slot.endAt)}\nSlot: ${slot.id}',
                    ),
                    selected: selectedSlot == slot.id,
                    trailing: selectedSlot == slot.id
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: loading || sending || needsReconciliation
                        ? null
                        : () => setState(() => selectedSlot = slot.id),
                  ),
                ),
              ),
          FilledButton(
            key: const Key('book'),
            onPressed:
                selectedSlot == null ||
                    loading ||
                    sending ||
                    needsReconciliation
                ? null
                : book,
            child: Text(sending ? 'Đang đặt…' : 'Đặt lịch • tự xác nhận'),
          ),
        ],
        const SizedBox(height: 24),
        Text('Lịch của tôi', style: Theme.of(context).textTheme.headlineSmall),
        if (!loading && bookings.isEmpty)
          const Text('Chưa có booking trong khoảng xem.'),
        ...bookings.map(
          (booking) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Booking: ${booking.id}\nPT: ${booking.ptId}\n${vietnamTime(booking.startAt)} → ${vietnamTime(booking.endAt)}\n${booking.status}',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
