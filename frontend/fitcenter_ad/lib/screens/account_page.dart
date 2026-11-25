import 'package:flutter/material.dart';

import '../services/admin_account_service.dart';
import '../services/api_client.dart';

class AccountsPage extends StatefulWidget {
  final AdminAccountService service;
  final VoidCallback onLogout;
  const AccountsPage({
    super.key,
    required this.service,
    required this.onLogout,
  });
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  String _role = 'MEMBER', _query = '', _status = 'Tất cả';
  List<AdminAccount> _rows = [];
  bool _loading = true, _modal = false;
  String? _error;
  int _read = 0;
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
    if (_current)
      setState(() {
        _loading = true;
        _error = null;
        _rows = [];
      });
    try {
      final rows = await widget.service.list(role);
      if (_current && read == _read)
        setState(() {
          _rows = rows;
          _loading = false;
        });
    } on ApiError catch (e) {
      if (_current && read == _read)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  Future<void> _add() async {
    if (_modal || !_current) return;
    setState(() => _modal = true);
    final created = await showDialog<AdminAccount>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) =>
          _AccountDialog(service: widget.service, role: _role, reload: _load),
    );
    if (!mounted || !_current) return;
    setState(() {
      _modal = false;
      if (created != null) _role = created.role;
    });
    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã tạo tài khoản chưa kích hoạt. Mã: ${created.userId}',
          ),
        ),
      );
      await _load();
    }
  }

  void _unavailable() =>
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chưa khả dụng')));
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), primary = theme.colorScheme.primary;
    final rows = _rows
        .where(
          (a) =>
              (a.fullName.toLowerCase().contains(_query) ||
                  a.email.toLowerCase().contains(_query)) &&
              (_status == 'Tất cả' || a.statusLabel == _status),
        )
        .toList();
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc email...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: DropdownButtonFormField<String>(
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
                    'Đã tạm khóa',
                    'Đã vô hiệu hóa',
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
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final a = rows[index], active = a.status == 'ACTIVE';
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: primary.withValues(
                                    alpha: 0.13,
                                  ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        a.email,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(a.statusLabel),
                                      SelectableText('User: ${a.userId}'),
                                      SelectableText('Profile: ${a.profileId}'),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Sửa tài khoản — Chưa khả dụng',
                                  onPressed: _unavailable,
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Xóa tài khoản — Chưa khả dụng',
                                  onPressed: _unavailable,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                                Switch(
                                  value: active,
                                  onChanged: (_) => _unavailable(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  final AdminAccountService service;
  final String role;
  final Future<void> Function() reload;
  const _AccountDialog({
    required this.service,
    required this.role,
    required this.reload,
  });
  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _form = GlobalKey<FormState>(),
      _name = TextEditingController(),
      _email = TextEditingController();
  late String _role = widget.role;
  bool _busy = false, _unknown = false;
  String? _error;
  late final int _epoch = widget.service.api.sessionEpoch;
  bool get _current =>
      mounted &&
      widget.service.api.authenticated &&
      widget.service.api.sessionEpoch == _epoch;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _unknown || !_current || !_form.currentState!.validate())
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await widget.service.create(
        _role,
        _email.text,
        _name.text,
      );
      if (mounted && _current) Navigator.pop(context, account);
    } on ApiError catch (e) {
      if (_current)
        setState(() {
          _busy = false;
          _unknown = e.outcomeUnknown;
          _error =
              '${e.toString()}${_unknown ? '\nChưa rõ kết quả. Không gửi lại; tải lại danh sách để đối chiếu.' : ''}';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Thêm tài khoản'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_busy && !_unknown,
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
                  controller: _email,
                  enabled: !_busy && !_unknown,
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: const [
                    DropdownMenuItem(value: 'MEMBER', child: Text('Hội viên')),
                    DropdownMenuItem(
                      value: 'PT',
                      child: Text('Huấn luyện viên'),
                    ),
                  ],
                  onChanged: _busy || _unknown
                      ? null
                      : (v) {
                          if (v != null) setState(() => _role = v);
                        },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tạo tài khoản chưa kích hoạt, không kích hoạt gói hội viên.',
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
          onPressed: _busy || _unknown ? null : _save,
          child: const Text('Thêm'),
        ),
      ],
    ),
  );
}
