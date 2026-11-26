import 'package:flutter/material.dart';

import '../services/account_manage_service.dart';
import '../services/admin_account_service.dart';
import '../services/api_client.dart';
import '../services/initial_activation_service.dart';
import '../services/kiosk_desk_service.dart';
import '../services/membership_plan_service.dart';
import '../services/report_service.dart';
import 'attendance_history_dialog.dart';
import 'account_edit_dialog.dart';
import 'desktop_shell.dart';
import 'face_enroll_dialog.dart';
import 'phone_number.dart';
import 'plan_form.dart';
import 'table_style.dart';

enum _Action { edit, plan, face, removeFace, history, delete }

class AccountsPage extends StatefulWidget {
  final AdminAccountService service;
  final VoidCallback onLogout;

  /// Set when a camera screen is connected: adding an account then continues
  /// straight to taking the face.
  final KioskDeskService? kiosk;
  const AccountsPage({
    super.key,
    required this.service,
    required this.onLogout,
    this.kiosk,
  });
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  String _role = 'MEMBER', _query = '', _status = 'Tất cả';
  List<AdminAccount> _rows = [];
  Map<String, AccountDetail>? _details;
  // null: not read (yet); the table then shows a dash.
  List<Visit>? _visits;
  bool _loading = true, _modal = false;
  String? _error;
  int _read = 0;
  late final _manage = AccountManageService(widget.service.api);
  late final int _epoch = widget.service.api.sessionEpoch;
  bool get _current =>
      mounted &&
      widget.service.api.authenticated &&
      widget.service.api.sessionEpoch == _epoch;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final read = ++_read, role = _role;
    if (_current) {
      setState(() {
        _loading = true;
        _error = null;
        _rows = [];
        _details = null;
        _visits = null;
      });
    }
    try {
      final rows = await widget.service.list(role);
      if (_current && read == _read) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
        final details = await _manage.details();
        if (_current && read == _read) setState(() => _details = details);
        await _loadVisits(read);
      }
    } on ApiError catch (e) {
      if (_current && read == _read) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadVisits(int read) async {
    if (!_current || read != _read) return;
    final today = vietnamToday();
    try {
      final visits = await ReportService(widget.service.api).attendance(
        today.subtract(const Duration(days: attendanceDays - 1)),
        today,
      );
      if (_current && read == _read) setState(() => _visits = visits);
    } on ApiError {
      // Not the same as "never checked in", so the column stays a dash.
    }
  }

  void _say(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<T?> _dialog<T>(Widget Function(BuildContext) builder) async {
    if (_modal || !_current) return null;
    setState(() => _modal = true);
    final result = await showDialog<T>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: builder,
    );
    if (mounted) setState(() => _modal = false);
    return result;
  }

  Future<void> _add() async {
    final created = await _dialog<_Created>(
      (_) => _AccountDialog(
        service: widget.service,
        role: _role,
        reload: _load,
        takesFace: widget.kiosk != null,
      ),
    );
    if (created == null || !_current) return;
    final account = created.account;
    setState(() => _role = account.role);
    _say(
      created.planName != null
          ? 'Đã tạo tài khoản và kích hoạt gói ${created.planName}.'
          : 'Đã tạo tài khoản chưa kích hoạt.',
    );
    await _load();
    // The package did not clearly go through: finish that before the face.
    if (created.failure != null && _current) {
      await _plan(account, created.failure);
    }
    if (widget.kiosk != null && _current) await _face(account);
  }

  Future<void> _plan(AdminAccount account, [PlanFailure? failure]) async {
    final planName = await _dialog<String>(
      (_) => PlanDialog(
        api: widget.service.api,
        account: account,
        failure: failure,
      ),
    );
    if (!_current) return;
    if (planName != null) {
      _say('Đã kích hoạt gói $planName cho ${account.fullName}.');
    }
    await _load();
  }

  Future<void> _face(AdminAccount account) async {
    await _dialog<bool>(
      (_) => FaceEnrollDialog(
        kiosk: widget.kiosk!,
        profileId: account.profileId,
        name: account.fullName,
      ),
    );
    if (_current) await _load();
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await _dialog<bool>(
        (dialog) => AlertDialog(
          title: Text(title),
          content: SizedBox(width: 420, child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const Key('confirm-action'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _change(Future<void> Function() action, String done) async {
    try {
      await action();
      _say(done);
    } on ApiError catch (e) {
      _say(e.toString());
    }
    if (_current) await _load();
  }

  Future<void> _run(_Action action, AdminAccount a) async {
    if (_modal || !_current) return;
    switch (action) {
      case _Action.edit:
        final saved = await _dialog<bool>(
          (_) => AccountEditDialog(
            service: _manage,
            account: a,
            phone: _details?[a.profileId]?.phone,
          ),
        );
        if (saved == true && _current) {
          _say('Đã lưu thay đổi.');
          await _load();
        }
      case _Action.plan:
        await _plan(a);
      case _Action.face:
        await _face(a);
      case _Action.removeFace:
        if (await _confirm(
          'Xóa khuôn mặt',
          'Xóa khuôn mặt của ${a.fullName} khỏi màn hình camera? Người này sẽ '
              'không check-in được cho tới khi chụp lại.',
          'Xóa khuôn mặt',
        )) {
          await _change(
            () => _manage.removeFace(a.profileId),
            'Đã gửi yêu cầu xóa khuôn mặt tới màn hình camera.',
          );
        }
      case _Action.history:
        await _dialog<void>(
          (_) => AttendanceHistoryDialog(
            name: a.fullName,
            visits: _visitsOf(a) ?? const [],
          ),
        );
      case _Action.delete:
        if (await _confirm(
          'Xóa tài khoản',
          'Xóa hẳn tài khoản ${a.fullName} (${a.email})? Không khôi phục được. '
              'Tài khoản đã có gói, thanh toán hoặc lịch tập sẽ không xóa được.',
          'Xóa',
        )) {
          await _change(() => _manage.delete(a.userId), 'Đã xóa tài khoản.');
        }
    }
  }

  /// Newest first, as the server sends them.
  List<Visit>? _visitsOf(AdminAccount a) =>
      _visits?.where((v) => v.profileId == a.profileId).toList();

  _RowView _view(AdminAccount a) => _RowView(
    account: a,
    visits: _visitsOf(a),
    detail: _details?[a.profileId],
    camera: widget.kiosk != null,
    onAction: _modal ? null : (action) => _run(action, a),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _rows.where((a) {
      final phone = _details?[a.profileId]?.phone ?? '';
      return (a.fullName.toLowerCase().contains(_query) ||
              a.email.toLowerCase().contains(_query) ||
              phone.contains(_query)) &&
          (_status == 'Tất cả' || a.statusLabel == _status);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hội viên & PT',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại tài khoản',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (!AdminDesktopScope.isDesktop(context))
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _modal || _loading || _error != null ? null : _add,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm tài khoản'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'MEMBER',
                      label: Text('Hội viên'),
                      icon: Icon(Icons.people_outline),
                    ),
                    ButtonSegment(
                      value: 'PT',
                      label: Text('Huấn luyện viên'),
                      icon: Icon(Icons.fitness_center),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) {
                    setState(() {
                      _role = s.first;
                      _query = '';
                    });
                    _load();
                  },
                ),
              ),
            ),
            _FilterBar(
              search: TextField(
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, email hoặc số điện thoại...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              status: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: 'Lọc theo trạng thái',
                  prefixIcon: const Icon(Icons.filter_list),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: [
                  for (final s in [
                    'Tất cả',
                    'Đang hoạt động',
                    'Chưa kích hoạt',
                  ])
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (s) {
                  if (s != null) setState(() => _status = s);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _role == 'MEMBER' ? 'DANH SÁCH HỘI VIÊN' : 'DANH SÁCH PT',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    '${rows.length} tài khoản',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
            Expanded(
              child: !_loading && _error == null && rows.isEmpty
                  ? const Center(
                      child: Text('Không tìm thấy tài khoản phù hợp.'),
                    )
                  : LayoutBuilder(
                      builder: (context, box) => box.maxWidth >= _tableWidth
                          ? _AccountTable(
                              role: _role,
                              camera: widget.kiosk != null,
                              rows: [for (final a in rows) _view(a)],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                              itemCount: rows.length,
                              itemBuilder: (context, index) =>
                                  _AccountCard(_view(rows[index])),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

const _tableWidth = 820.0;

class _FilterBar extends StatelessWidget {
  final Widget search, status;
  const _FilterBar({required this.search, required this.status});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: box.maxWidth >= _tableWidth
          ? Row(
              children: [
                Expanded(flex: 2, child: search),
                const SizedBox(width: 16),
                Expanded(child: status),
              ],
            )
          : Column(children: [search, const SizedBox(height: 16), status]),
    ),
  );
}

/// One account as both the table and the cards show it.
class _RowView {
  final AdminAccount account;
  final AccountDetail? detail;
  final List<Visit>? visits;
  final bool camera;
  final void Function(_Action action)? onAction;
  const _RowView({
    required this.account,
    required this.visits,
    required this.detail,
    required this.camera,
    required this.onAction,
  });

  /// A dash means the server did not say; it never means "no package".
  String get planText {
    final d = detail;
    if (d == null) return '—';
    if (d.planState == null) return 'Chưa có gói';
    final until = d.validUntil == null
        ? ''
        : ' đến ${showCalendar(d.validUntil!)}';
    return switch (d.planState) {
      'ACTIVE' => '${d.planName}\nCòn hạn$until',
      'EXPIRED' => '${d.planName}\nHết hạn$until',
      'UPCOMING' => '${d.planName}\nChưa tới ngày bắt đầu',
      _ => '${d.planName}\nKhông hiệu lực',
    };
  }

  bool get canAddPlan =>
      account.role == 'MEMBER' && detail != null && detail!.planState == null;

  /// Last check-in; opens the whole history.
  Widget get historyButton {
    final list = visits;
    final last = list == null || list.isEmpty
        ? null
        : vietnamClock(list.first.at);
    return TextButton.icon(
      key: ValueKey('history-${account.profileId}'),
      onPressed: list == null || onAction == null
          ? null
          : () => onAction!(_Action.history),
      icon: const Icon(Icons.history, size: 18),
      label: Text(
        list == null
            ? '—'
            : last == null
            ? 'Chưa có'
            : '${shortDay(last)} ${clockText(last)}',
      ),
    );
  }

  String get faceText => switch (detail?.face) {
    'ENROLLED' => 'Đã đăng ký',
    'REMOVING' => 'Đang xóa',
    'NONE' => 'Chưa có',
    _ => '—',
  };

  Widget _button(
    _Action action,
    String key,
    String tooltip,
    IconData icon, {
    bool enabled = true,
  }) => IconButton(
    key: ValueKey('$key-${account.profileId}'),
    tooltip: tooltip,
    onPressed: !enabled || onAction == null ? null : () => onAction!(action),
    icon: Icon(icon, size: 20),
  );

  List<Widget> get buttons => [
    _button(_Action.edit, 'edit', 'Sửa', Icons.edit_outlined),
    if (canAddPlan)
      _button(
        _Action.plan,
        'plan',
        'Đăng ký gói tập',
        Icons.card_membership_outlined,
      ),
    if (camera)
      _button(
        _Action.face,
        'face',
        detail?.face == 'ENROLLED' ? 'Chụp lại khuôn mặt' : 'Chụp khuôn mặt',
        Icons.add_a_photo_outlined,
        // A queued removal would delete a face captured now.
        enabled: account.status != 'SUSPENDED' && detail?.face != 'REMOVING',
      ),
    if (camera && detail?.face == 'ENROLLED')
      _button(
        _Action.removeFace,
        'remove-face',
        'Xóa khuôn mặt',
        Icons.face_retouching_off,
      ),
    _button(_Action.delete, 'delete', 'Xóa tài khoản', Icons.delete_outline),
  ];
}

/// Desktop view of the same server data as the cards.
class _AccountTable extends StatelessWidget {
  final String role;
  final bool camera;
  final List<_RowView> rows;
  const _AccountTable({
    required this.role,
    required this.camera,
    required this.rows,
  });
  @override
  Widget build(BuildContext context) {
    final member = role == 'MEMBER';
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: box.maxWidth - 40),
            child: DataTable(
              border: tableGrid(context),
              headingRowColor: tableHeading(context),
              headingTextStyle: tableHeadingStyle,
              columnSpacing: 24,
              horizontalMargin: 12,
              dataRowMaxHeight: 68,
              columns: [
                DataColumn(
                  label: Text(member ? 'Hội viên' : 'Huấn luyện viên'),
                ),
                if (member) const DataColumn(label: Text('Số điện thoại')),
                if (member) const DataColumn(label: Text('Gói tập')),
                if (camera) const DataColumn(label: Text('Khuôn mặt')),
                const DataColumn(label: Text('Check-in gần nhất')),
                const DataColumn(label: Text('Thao tác')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.account.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              row.account.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (member) DataCell(Text(row.detail?.phone ?? '—')),
                      if (member) DataCell(Text(row.planText)),
                      if (camera) DataCell(Text(row.faceText)),
                      DataCell(row.historyButton),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: row.buttons,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final _RowView row;
  const _AccountCard(this.row);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), primary = theme.colorScheme.primary;
    final a = row.account;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: primary.withValues(alpha: 0.13),
              child: Icon(
                a.role == 'MEMBER'
                    ? Icons.person_outline
                    : Icons.fitness_center,
                color: primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(a.email, style: theme.textTheme.bodySmall),
                  if (row.detail?.phone != null) Text(row.detail!.phone!),
                  const SizedBox(height: 8),
                  Text(a.statusLabel),
                  if (a.role == 'MEMBER' && row.detail != null)
                    Text(row.planText),
                  if (row.camera) Text('Khuôn mặt: ${row.faceText}'),
                  if (row.visits != null) row.historyButton,
                  Wrap(children: row.buttons),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Created {
  final AdminAccount account;
  final String? planName;
  final PlanFailure? failure;
  const _Created(this.account, {this.planName, this.failure});
}

/// Account and, for a member, the first package in one step.
class _AccountDialog extends StatefulWidget {
  final AdminAccountService service;
  final String role;
  final Future<void> Function() reload;
  final bool takesFace;
  const _AccountDialog({
    required this.service,
    required this.role,
    required this.reload,
    required this.takesFace,
  });
  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _form = GlobalKey<FormState>(),
      _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _receipt = TextEditingController();
  late String _role = widget.role;
  List<MembershipPlan> _plans = [];
  String? _planId;
  bool _busy = false, _unknown = false;
  String? _error;
  late final int _epoch = widget.service.api.sessionEpoch;
  bool get _current =>
      mounted &&
      widget.service.api.authenticated &&
      widget.service.api.sessionEpoch == _epoch;
  MembershipPlan? get _plan => _plans.where((p) => p.id == _planId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await MembershipPlanService(widget.service.api).list();
      if (_current) setState(() => _plans = plans);
    } on ApiError {
      // The account can still be added; the package has its own button.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _receipt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _unknown || !_current || !_form.currentState!.validate()) {
      return;
    }
    final member = _role == 'MEMBER';
    final plan = member ? _plan : null;
    final request = plan == null ? null : PlanRequest(plan, _receipt.text);
    setState(() {
      _busy = true;
      _error = null;
    });
    final AdminAccount account;
    try {
      account = await widget.service.create(
        _role,
        _email.text,
        _name.text,
        phone: member ? normalizePhone(_phone.text) : null,
      );
    } on ApiError catch (e) {
      if (_current) {
        setState(() {
          _busy = false;
          _unknown = e.outcomeUnknown;
          _error =
              '${e.toString()}${_unknown ? '\nChưa rõ kết quả. Không gửi lại; tải lại danh sách để đối chiếu.' : ''}';
        });
      }
      return;
    }
    var created = _Created(account);
    if (request != null && _current) {
      try {
        await InitialActivationService(widget.service.api)
            .create(account.profileId, request.key, request.payload);
        created = _Created(account, planName: request.planName);
      } on ApiError catch (e) {
        created = _Created(account, failure: PlanFailure.from(request, e));
      }
    }
    if (mounted && _current) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _unknown;
    final member = _role == 'MEMBER';
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Thêm tài khoản'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Vai trò'),
                    items: const [
                      DropdownMenuItem(
                        value: 'MEMBER',
                        child: Text('Hội viên'),
                      ),
                      DropdownMenuItem(
                        value: 'PT',
                        child: Text('Huấn luyện viên'),
                      ),
                    ],
                    onChanged: locked
                        ? null
                        : (v) {
                            if (v != null) setState(() => _role = v);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('add-name'),
                    controller: _name,
                    enabled: !locked,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty || v.runes.length > 150
                        ? 'Nhập họ tên, tối đa 150 ký tự.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('add-email'),
                    controller: _email,
                    enabled: !locked,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        v == null ||
                            v.trim().length > 255 ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(v.trim())
                        ? 'Email chưa hợp lệ.'
                        : null,
                  ),
                  if (member) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('add-phone'),
                      controller: _phone,
                      enabled: !locked,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: phoneError,
                    ),
                    if (_plans.isEmpty) ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Gói tập: chưa có gói nào để chọn. Tạo ở mục Gói tập.',
                        ),
                      ),
                    ],
                    if (_plans.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: const Key('add-plan'),
                        initialValue: _planId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Gói tập',
                          prefixIcon: Icon(Icons.card_membership_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            child: Text('Chưa đăng ký gói'),
                          ),
                          for (final p in _plans)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(planLabel(p)),
                            ),
                        ],
                        onChanged: locked
                            ? null
                            : (v) => setState(() => _planId = v),
                      ),
                    ],
                    if (_plan != null) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('add-receipt'),
                        controller: _receipt,
                        enabled: !locked,
                        decoration: const InputDecoration(
                          labelText: 'Mã chứng từ thu tiền tại quầy',
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                        ),
                        validator: receiptError,
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Text(
                    [
                      if (member && _plan != null)
                        'Bấm nút bên dưới là xác nhận đã thu đủ tiền tại quầy.',
                      'Người dùng tự kích hoạt đăng nhập bằng email.',
                      if (widget.takesFace)
                        'Thêm xong sẽ chuyển sang chụp khuôn mặt.',
                    ].join(' '),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null) Text(_error!),
                  if (_unknown)
                    TextButton(
                      onPressed: widget.reload,
                      child: const Text('Tải lại danh sách để đối chiếu'),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: locked ? null : _save,
            child: Text(member && _plan != null ? 'Thêm và thu tiền' : 'Thêm'),
          ),
        ],
      ),
    );
  }
}
