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
  late final int epoch = widget.service.api.sessionEpoch;
  int loadVersion = 0;
  bool get alive => mounted && epoch == widget.service.api.sessionEpoch;
  bool get blocked => loading || sending || needsReconciliation;
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
    final version = ++loadVersion;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.service.slots(from, to),
        widget.service.bookings(from, to),
      ]);
      if (!alive || version != loadVersion) return;
      setState(() {
        slots = results[0] as List<Slot>;
        bookings = results[1] as List<Booking>;
        if (manual) needsReconciliation = false;
      });
    } on ApiError catch (failure) {
      if (alive) setState(() => error = failure.toString());
    } catch (_) {
      if (alive) {
        setState(
          () => error =
              'Không thể đọc dữ liệu máy chủ; không có dữ liệu demo thay thế.',
        );
      }
    } finally {
      if (alive && version == loadVersion) setState(() => loading = false);
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
      if (!alive) return;
      setState(() {
        message =
            'Tạo slot thành công • ${slot.status}\nSlot: ${slot.id}\n${vietnamTime(slot.startAt)} → ${vietnamTime(slot.endAt)}';
        startInput.clear();
      });
      await load();
    } on ApiError catch (failure) {
      if (!alive) return;
      setState(() {
        error = failure.toString();
        needsReconciliation = failure.outcomeUnknown || failure.status == 401;
      });
      if (failure.status == 409) {
        final conflict = failure.toString();
        await load();
        if (alive) setState(() => error = conflict);
      }
    } catch (_) {
      if (alive) {
        setState(() {
          needsReconciliation = true;
          error =
              'Chưa thể xác nhận kết quả. Hãy tải lại slot trước khi thử lại.';
        });
      }
    } finally {
      if (alive) setState(() => sending = false);
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (blocked) return;
    setState(() {
      sending = true;
      message = null;
      error = null;
    });
    try {
      await action();
    } on ApiError catch (failure) {
      if (!alive) return;
      setState(() {
        error = failure.toString();
        needsReconciliation = failure.outcomeUnknown || failure.status == 401;
      });
      if (failure.status == 409 || failure.status == 404) {
        await load();
        if (alive) setState(() => error = failure.toString());
      }
    } catch (_) {
      if (alive)
        setState(() {
          needsReconciliation = true;
          error =
              'Chưa xác nhận được kết quả. Tải lại dữ liệu trước thao tác mới.';
        });
    } finally {
      if (alive) setState(() => sending = false);
    }
  }

  Future<bool> confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              key: const Key('confirm-action'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ==
      true;

  Future<String?> input(
    String title,
    String label, {
    String initial = '',
    bool date = false,
  }) async {
    var value = initial;
    String? validation;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('action-input'),
                  initialValue: initial,
                  autofocus: true,
                  maxLines: date ? 1 : 3,
                  decoration: InputDecoration(
                    labelText: label,
                    errorText: validation,
                  ),
                  onChanged: (s) => value = s,
                ),
                if (date)
                  const Text(
                    'Giờ Việt Nam • YYYY-MM-DD HH:mm. Kết thúc = bắt đầu + 90 phút.',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              key: const Key('submit-input'),
              onPressed: () {
                try {
                  if (value.trim().isEmpty)
                    throw const FormatException('Không được để trống.');
                  if (date) parseVietnamInput(value.trim());
                  Navigator.pop(context, value.trim());
                } on FormatException catch (e) {
                  change(() => validation = e.message);
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> edit(Slot slot) => perform(() async {
    final raw = await input(
      'Sửa slot ${shortId(slot.id)}',
      'Bắt đầu (giờ Việt Nam)',
      initial: vietnamInput(slot.startAt),
      date: true,
    );
    if (raw == null || !alive) return;
    final next = await widget.service.edit(slot, parseVietnamInput(raw));
    if (!alive) return;
    setState(() {
      slots = slots.map((s) => s.id == slot.id ? next : s).toList();
      message =
          'Đã cập nhật slot • ${next.status}\nSlot hiện tại: ${next.id}${next.id == slot.id ? "" : "\nThay thế slot: ${slot.id}"}';
    });
    await load();
  });

  Future<void> remove(Slot slot) => perform(() async {
    if (!await confirm(
          'Loại slot khỏi availability',
          'Slot: ${slot.id}\nMáy chủ giữ lịch sử và loại slot khỏi danh sách khả dụng.',
        ) ||
        !alive)
      return;
    await widget.service.remove(slot);
    if (!alive) return;
    setState(
      () => message = 'Đã loại slot khỏi availability\nSlot: ${slot.id}',
    );
    await load();
  });

  Future<void> cancel(Booking booking) => perform(() async {
    final reason = await input(
      'Hủy session ${shortId(booking.id)}',
      'Lý do hủy bắt buộc',
    );
    if (reason == null || !alive) return;
    final next = await widget.service.cancel(booking, reason);
    if (!alive) return;
    setState(() {
      bookings = bookings.map((b) => b.id == next.id ? next : b).toList();
      message =
          'Đã hủy session • ${next.status}\nBooking: ${next.id}\nLý do: ${next.cancelReason}';
    });
    await load();
  });

  Future<void> complete(Booking booking) => perform(() async {
    if (!await confirm(
          'Hoàn tất session',
          'Booking: ${booking.id}\nMáy chủ quyết định buổi tập đã kết thúc hay chưa.',
        ) ||
        !alive)
      return;
    final next = await widget.service.complete(booking);
    if (!alive) return;
    setState(() {
      bookings = bookings.map((b) => b.id == next.id ? next : b).toList();
      message =
          'Hoàn tất session • ${next.status}\nBooking: ${next.id}\n${vietnamTime(next.completedAt!)}';
    });
    await load();
  });

  Future<void> checkEligibility(Booking booking) => perform(() async {
    final result = await widget.service.eligibility(booking);
    if (!alive) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.eligible
              ? 'Đủ điều kiện tại thời điểm kiểm tra'
              : 'Chưa đủ điều kiện',
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Booking: ${booking.id}\nKiểm tra lúc: ${vietnamTime(result.checkedAt)}\nUTC: ${result.checkedAt.toIso8601String()}',
              ),
              ...result.reasonCodes.map(
                (code) => Text('${eligibilityReason(code)} [$code]'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Chỉ phản ánh điều kiện hiện tại; có thể thay đổi sau phản hồi. Không ghi nhận bắt đầu buổi tập.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('close-eligibility'),
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  });

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slot: ${slot.id}\n${vietnamTime(slot.startAt)} → ${vietnamTime(slot.endAt)}\n${slot.status}',
                  ),
                  if (slot.status == 'AVAILABLE')
                    Wrap(
                      spacing: 12,
                      children: [
                        OutlinedButton(
                          key: ValueKey('edit-${slot.id}'),
                          onPressed: blocked ? null : () => edit(slot),
                          child: Text('Sửa slot ${shortId(slot.id)}'),
                        ),
                        OutlinedButton(
                          key: ValueKey('delete-${slot.id}'),
                          onPressed: blocked ? null : () => remove(slot),
                          child: Text('Loại slot ${shortId(slot.id)}'),
                        ),
                      ],
                    ),
                ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking: ${booking.id}\nMember: ${shortId(booking.memberId)}\n${vietnamTime(booking.startAt)} → ${vietnamTime(booking.endAt)}\n${booking.status}',
                  ),
                  if (booking.cancelledAt != null)
                    Text(
                      'Hủy bởi ${booking.cancelledBy} • ${vietnamTime(booking.cancelledAt!)}',
                    ),
                  if (booking.cancelReason != null)
                    Text('Lý do: ${booking.cancelReason}'),
                  if (booking.completedAt != null)
                    Text('Hoàn tất: ${vietnamTime(booking.completedAt!)}'),
                  Wrap(
                    spacing: 12,
                    children: [
                      OutlinedButton(
                        key: ValueKey('eligibility-${booking.id}'),
                        onPressed: blocked
                            ? null
                            : () => checkEligibility(booking),
                        child: Text(
                          'Kiểm tra điều kiện ${shortId(booking.id)}',
                        ),
                      ),
                      if (booking.status == 'CONFIRMED') ...[
                        OutlinedButton(
                          key: ValueKey('cancel-${booking.id}'),
                          onPressed: blocked ? null : () => cancel(booking),
                          child: Text('Hủy session ${shortId(booking.id)}'),
                        ),
                        FilledButton(
                          key: ValueKey('complete-${booking.id}'),
                          onPressed: blocked ? null : () => complete(booking),
                          child: Text('Hoàn tất ${shortId(booking.id)}'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
