
import 'package:flutter/material.dart';

class InitialActivationPage extends StatefulWidget {
  const InitialActivationPage({super.key});

  @override
  State<InitialActivationPage> createState() =>
      _InitialActivationPageState();
}

class _InitialActivationPageState extends State<InitialActivationPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _paymentEvidenceController = TextEditingController();

  final List<Map<String, dynamic>> _plans = [
    {'name': 'Gói 1 tháng', 'months': 1},
    {'name': 'Gói 3 tháng', 'months': 3},
    {'name': 'Gói 6 tháng', 'months': 6},
    {'name': 'Gói 12 tháng', 'months': 12},
  ];

  String? _selectedPlan;
  bool _offlinePaymentConfirmed = false;
  bool _membershipActivated = false;
  bool _faceEnrolled = false;
  DateTime? _startDate;
  DateTime? _expiryDate;
  String _message = '';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _paymentEvidenceController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa xác định';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _activateMembership() {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _message = 'Vui lòng kiểm tra lại thông tin bắt buộc.';
      });
      return;
    }

    if (_selectedPlan == null) {
      setState(() {
        _message = 'Vui lòng chọn Gói hội viên.';
      });
      return;
    }

    if (!_offlinePaymentConfirmed) {
      setState(() {
        _message = 'Cần xác nhận thanh toán trực tiếp đã hoàn tất.';
      });
      return;
    }

    final plan = _plans.firstWhere(
          (item) => item['name'] == _selectedPlan,
    );

    final start = DateTime.now();
    final expiry = DateTime(
      start.year,
      start.month + plan['months'] as int,
      start.day,
    );

    setState(() {
      _startDate = start;
      _expiryDate = expiry;
      _membershipActivated = true;
      _faceEnrolled = false;
      _message =
      'Kích hoạt thành công; chưa đăng ký khuôn mặt.';
    });
  }

  void _simulateFaceEnrollment() {
    if (!_membershipActivated) {
      setState(() {
        _message = 'Hãy kích hoạt Gói hội viên trước.';
      });
      return;
    }

    setState(() {
      _faceEnrolled = true;
      _message =
      'Mô phỏng đăng ký khuôn mặt thành công. '
          'Chưa kết nối camera/kiosk thật.';
    });
  }

  void _retryFaceEnrollment() {
    if (!_membershipActivated) return;

    setState(() {
      _faceEnrolled = false;
      _message =
      'Có thể thử đăng ký khuôn mặt lại. '
          'Membership vẫn giữ trạng thái ACTIVE.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kích hoạt Gói hội viên'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Kích hoạt hội viên lần đầu',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhập thông tin hội viên, chọn gói tập và xác nhận '
                'thanh toán trực tiếp trước khi kích hoạt.',
          ),
          const SizedBox(height: 20),

          Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Thông tin Member',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập họ và tên.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập số điện thoại.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Vui lòng nhập email.';
                        }
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Email không hợp lệ.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),
                    Text(
                      '2. Gói hội viên',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _selectedPlan,
                      decoration: const InputDecoration(
                        labelText: 'Chọn gói hội viên *',
                        border: OutlineInputBorder(),
                      ),
                      items: _plans.map((plan) {
                        return DropdownMenuItem<String>(
                          value: plan['name'] as String,
                          child: Text(plan['name'] as String),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPlan = value;
                          _membershipActivated = false;
                          _faceEnrolled = false;
                          _startDate = null;
                          _expiryDate = null;
                          _message = '';
                        });
                      },
                    ),

                    const SizedBox(height: 24),
                    Text(
                      '3. Xác nhận thanh toán trực tiếp',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _offlinePaymentConfirmed,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Thanh toán offline đã hoàn tất',
                      ),
                      subtitle: const Text(
                        'Xác nhận theo quy trình thanh toán của phòng gym.',
                      ),
                      onChanged: _membershipActivated
                          ? null
                          : (value) {
                        setState(() {
                          _offlinePaymentConfirmed = value ?? false;
                          _message = '';
                        });
                      },
                    ),

                    TextFormField(
                      controller: _paymentEvidenceController,
                      decoration: const InputDecoration(
                        labelText: 'Mã biên nhận / ghi chú thanh toán',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed:
                      _membershipActivated ? null : _activateMembership,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Kích hoạt Gói hội viên'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '4. Trạng thái Gói hội viên',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _statusRow(
                    'Gói hội viên',
                    _membershipActivated ? 'ACTIVE' : 'Chưa kích hoạt',
                  ),
                  _statusRow('Gói tập', _selectedPlan ?? 'Chưa chọn'),
                  _statusRow('Ngày bắt đầu', _formatDate(_startDate)),
                  _statusRow('Ngày hết hạn', _formatDate(_expiryDate)),
                  _statusRow(
                    'Face Check-in',
                    _faceEnrolled
                        ? 'Sẵn sàng (mô phỏng)'
                        : 'Chưa khả dụng',
                  ),

                  if (_membershipActivated) ...[
                    const Divider(height: 24),
                    Text(
                      '5. Đăng ký khuôn mặt',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Đăng ký khuôn mặt tại camera/kiosk. '
                          'Nếu chưa thành công, Membership vẫn ACTIVE; '
                          'Face Check-in chỉ khả dụng sau khi có '
                          'FacialProfile hợp lệ.',
                    ),
                    const SizedBox(height: 12),
                    if (!_faceEnrolled)
                      FilledButton.icon(
                        onPressed: _simulateFaceEnrollment,
                        icon: const Icon(Icons.face),
                        label: const Text(
                          'Mô phỏng đăng ký khuôn mặt thành công',
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _retryFaceEnrollment,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử đăng ký lại'),
                      ),
                  ],
                ],
              ),
            ),
          ),

          if (_message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_message),
            ),
          ],

          const SizedBox(height: 12),
          const Text(
            'Lưu ý: dữ liệu và thao tác hiện chỉ dùng để thử giao diện; '
                'chưa tạo tài khoản thật, chưa ghi Membership vào database '
                'và chưa kết nối camera/kiosk.',
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
