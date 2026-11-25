import 'package:flutter/material.dart';

import '../services/face_enrollment_service.dart';
import '../services/admin_account_service.dart';
import '../services/api_client.dart';
import '../services/initial_activation_service.dart' show newActivationKey;
import '../services/vietnam_time.dart';

class FaceEnrollmentPage extends StatefulWidget {
  final FaceEnrollmentService service;
  const FaceEnrollmentPage({super.key, required this.service});
  @override
  State<FaceEnrollmentPage> createState() => _FaceEnrollmentPageState();
}

class _FaceEnrollmentPageState extends State<FaceEnrollmentPage> {
  List<AdminAccount> members = [];
  String? member, error, key, revokeKey;
  FaceEnrollmentState? data;
  bool loading = true,
      busy = false,
      consent = false,
      verified = false,
      atGym = false,
      uncertain = false;
  late final int epoch = widget.service.api.sessionEpoch;
  bool get current =>
      mounted &&
      widget.service.api.authenticated &&
      widget.service.api.sessionEpoch == epoch;
  @override
  void initState() {
    super.initState();
    loadMembers();
  }

  Future<void> loadMembers() async {
    try {
      final rows = await widget.service.members();
      if (current)
        setState(() {
          members = rows;
          loading = false;
        });
    } catch (e) {
      if (current)
        setState(() {
          error = e.toString();
          loading = false;
        });
    }
  }

  Future<void> reload() async {
    if (!current || busy || member == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await widget.service.read(member!);
      if (current)
        setState(() {
          data = value;
          if (key == null) uncertain = false;
          if (value.profiles.every((p) => p.status != 'ACTIVE'))
            revokeKey = null;
          if (key != null && value.enrollments.any((e) => e.requestId == key)) {
            uncertain = false;
            key = null;
          }
        });
    } catch (e) {
      if (current) setState(() => error = e.toString());
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (c) => AlertDialog(
          title: const Text('Xác nhận'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> start() async {
    if (!current ||
        busy ||
        uncertain ||
        member == null ||
        !consent ||
        !verified ||
        !atGym)
      return;
    key = newActivationKey();
    await command(() async {
      await widget.service.start(
        member!,
        key!,
        consent: consent,
        verified: verified,
        atGym: atGym,
      );
    }, startCommand: true);
  }

  Future<void> command(
    Future<void> Function() action, {
    bool startCommand = false,
  }) async {
    if (!current || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (!current) return;
      final value = await widget.service.read(member!);
      if (current)
        setState(() {
          data = value;
          uncertain = false;
          key = null;
          revokeKey = null;
        });
    } on ApiError catch (e) {
      if (current)
        setState(() {
          error = e.toString();
          uncertain = e.outcomeUnknown || e.status >= 500;
          if (!uncertain && startCommand) key = null;
        });
    } catch (_) {
      if (current)
        setState(() {
          error = 'Chưa rõ kết quả. Hãy tải lại trạng thái để đối chiếu.';
          uncertain = true;
        });
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> revoke(FaceProfile profile) async {
    if (!current || busy) return;
    setState(() => busy = true);
    final yes = await confirm(
      'Thu hồi quyền dùng mẫu khuôn mặt này? Máy chủ sẽ chặn check-in ngay; việc xóa mẫu được theo dõi riêng.',
    );
    if (!current) return;
    setState(() => busy = false);
    if (!yes) return;
    revokeKey ??= newActivationKey();
    await command(() async {
      await widget.service.revoke(member!, profile.id, revokeKey!);
    });
  }

  String label(String state) => switch (state) {
    'PENDING' => 'Đang chờ mẫu',
    'ACTIVE' => 'Đang hoạt động',
    'FAILED' => 'Đăng ký thất bại',
    'REVOKED' => 'Đã thu hồi',
    _ => state,
  };
  @override
  Widget build(BuildContext context) {
    final ops = data?.enrollments ?? <FaceEnrollment>[],
        profiles = data?.profiles ?? <FaceProfile>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký khuôn mặt')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Chế độ kiểm thử: mẫu mô phỏng. Chưa thu dữ liệu khuôn mặt người thật.',
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (members.isEmpty)
            const Text('Chưa có hội viên để đăng ký.'),
          if (error != null)
            Text(
              error!,
              key: const Key('face-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!loading && members.isNotEmpty)
            DropdownButtonFormField<String>(
              key: const Key('face-member'),
              initialValue: member,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Hội viên'),
              items: members
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.profileId,
                      child: Text(
                        '${m.fullName} • ${m.profileId.substring(0, 8)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy || uncertain
                  ? null
                  : (id) {
                      setState(() {
                        member = id;
                        data = null;
                        consent = false;
                        verified = false;
                        atGym = false;
                        key = null;
                      });
                      reload();
                    },
            ),
          if (member != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: busy ? null : reload,
              child: const Text('Tải lại trạng thái'),
            ),
            CheckboxListTile(
              key: const Key('face-verified'),
              value: verified,
              onChanged: busy
                  ? null
                  : (v) => setState(() => verified = v ?? false),
              title: const Text('Đã xác minh đúng hội viên'),
            ),
            CheckboxListTile(
              key: const Key('face-gym'),
              value: atGym,
              onChanged: busy
                  ? null
                  : (v) => setState(() => atGym = v ?? false),
              title: const Text('Thực hiện tại phòng gym'),
            ),
            CheckboxListTile(
              key: const Key('face-consent'),
              value: consent,
              onChanged: busy
                  ? null
                  : (v) => setState(() => consent = v ?? false),
              title: const Text('Hội viên đã đồng ý xử lý dữ liệu khuôn mặt'),
              subtitle: const Text(
                'Ghi nhận consent phiên bản face-consent-v1.',
              ),
            ),
            FilledButton(
              onPressed:
                  busy ||
                      uncertain ||
                      data == null ||
                      !consent ||
                      !verified ||
                      !atGym ||
                      ops.any((e) => e.status == 'PENDING')
                  ? null
                  : start,
              child: Text(
                profiles.any((p) => p.status == 'ACTIVE')
                    ? 'Bắt đầu đăng ký lại'
                    : 'Bắt đầu đăng ký',
              ),
            ),
            if (uncertain)
              const Text(
                'Kết quả gửi chưa rõ. Không tạo yêu cầu mới; hãy tải lại trạng thái để đối chiếu.',
              ),
            if (busy) const LinearProgressIndicator(),
            if (data != null && profiles.isEmpty && ops.isEmpty)
              const Text('Chưa có hồ sơ khuôn mặt.'),
            for (final p in profiles)
              Card(
                child: ListTile(
                  title: Text('${label(p.status)} • ${p.id.substring(0, 8)}'),
                  subtitle: Text(
                    p.mode == 'SIMULATED_TEST'
                        ? 'Mẫu mô phỏng'
                        : 'Nguồn cũ chưa xác minh',
                  ),
                  trailing: p.status == 'ACTIVE'
                      ? TextButton(
                          onPressed: busy || uncertain ? null : () => revoke(p),
                          child: const Text('Thu hồi'),
                        )
                      : null,
                ),
              ),
            for (final op in ops)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${label(op.status)} • ${op.id.substring(0, 8)}'),
                      Text(vietnamTime(op.startedAt)),
                      if (op.failureCode != null)
                        Text('Mẫu chưa được kích hoạt: ${op.failureCode}'),
                      if (op.cleanupPending)
                        const Text(
                          'Đang chờ đồng bộ xóa mẫu; quyền đã do máy chủ quyết định.',
                        ),
                      if (op.status == 'PENDING')
                        OutlinedButton(
                          onPressed: busy || uncertain
                              ? null
                              : () => command(() async {
                                  await widget.service.complete(member!, op.id);
                                }),
                          child: const Text('Kiểm tra mẫu và hoàn tất'),
                        ),
                      if (op.status == 'PENDING')
                        TextButton(
                          onPressed: busy || uncertain
                              ? null
                              : () async {
                                  setState(() => busy = true);
                                  final yes = await confirm(
                                    'Hủy yêu cầu đăng ký này? Mẫu hiện tại vẫn giữ nguyên.',
                                  );
                                  if (!current) return;
                                  setState(() => busy = false);
                                  if (yes)
                                    await command(() async {
                                      await widget.service.revokePending(
                                        member!,
                                        op.id,
                                      );
                                    });
                                },
                          child: const Text('Hủy đăng ký'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
