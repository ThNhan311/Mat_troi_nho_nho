
import 'package:flutter/material.dart';

class BookingPolicyPage extends StatefulWidget {
  const BookingPolicyPage({super.key});

  @override
  State<BookingPolicyPage> createState() => _BookingPolicyPageState();
}

class _BookingPolicyPageState extends State<BookingPolicyPage> {
  final _formKey = GlobalKey<FormState>();

  final _daysController = TextEditingController(text: '14');
  final _noticeHoursController = TextEditingController(text: '2');
  final _cancelHoursController = TextEditingController(text: '4');
  final _futureBookingsController = TextEditingController(text: '5');

  DateTime _effectiveFrom = DateTime.now();
  String? _saveMessage;

  @override
  void dispose() {
    _daysController.dispose();
    _noticeHoursController.dispose();
    _cancelHoursController.dispose();
    _futureBookingsController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String? _validateNumber(
      String? value, {
        required int minimum,
        required String fieldName,
      }) {
    final number = int.tryParse(value?.trim() ?? '');

    if (number == null) {
      return '$fieldName phải là số nguyên.';
    }

    if (number < minimum) {
      return '$fieldName phải từ $minimum trở lên.';
    }

    return null;
  }

  Future<void> _selectEffectiveDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (!mounted || selectedDate == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_effectiveFrom),
    );

    if (!mounted || selectedTime == null) return;

    setState(() {
      _effectiveFrom = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      _saveMessage = null;
    });
  }

  void _savePolicy() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _saveMessage = 'Chưa lưu: vui lòng kiểm tra các trường bị lỗi.';
      });
      return;
    }

    if (_effectiveFrom.isBefore(DateTime.now())) {
      setState(() {
        _saveMessage =
        'Ngày áp dụng đang ở quá khứ. Hãy kiểm tra lại trước khi lưu.';
      });
      return;
    }

    setState(() {
      _saveMessage =
      'Kiểm tra hợp lệ thành công. Đây là bản thử nghiệm giao diện; '
          'chính sách chưa được lưu lên máy chủ.';
    });
  }

  Widget _buildNumberField({
    required String title,
    required String label,
    required String suffix,
    required TextEditingController controller,
    required int minimum,
    required String fieldName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
          validator: (value) => _validateNumber(
            value,
            minimum: minimum,
            fieldName: fieldName,
          ),
          onChanged: (_) {
            setState(() {
              _saveMessage = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(
        value,
        textAlign: TextAlign.end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chính sách đặt lịch'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Quy định đặt lịch',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thiết lập thời gian và giới hạn đặt lịch PT.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNumberField(
                      title: 'Thời gian đặt lịch trước tối đa',
                      label: 'Số ngày',
                      suffix: 'ngày',
                      controller: _daysController,
                      minimum: 1,
                      fieldName: 'Thời gian đặt trước tối đa',
                    ),
                    const SizedBox(height: 20),

                    _buildNumberField(
                      title: 'Thời gian báo trước tối thiểu',
                      label: 'Số giờ',
                      suffix: 'giờ',
                      controller: _noticeHoursController,
                      minimum: 0,
                      fieldName: 'Thời gian báo trước tối thiểu',
                    ),
                    const SizedBox(height: 20),

                    _buildNumberField(
                      title: 'Thời hạn hủy lịch',
                      label: 'Hủy trước giờ tập',
                      suffix: 'giờ',
                      controller: _cancelHoursController,
                      minimum: 0,
                      fieldName: 'Thời hạn hủy lịch',
                    ),
                    const SizedBox(height: 20),

                    _buildNumberField(
                      title: 'Số lịch tương lai tối đa',
                      label: 'Số lịch',
                      suffix: 'lịch',
                      controller: _futureBookingsController,
                      minimum: 1,
                      fieldName: 'Số lịch tương lai tối đa',
                    ),

                    const Divider(height: 32),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_outlined),
                      title: const Text('Ngày bắt đầu áp dụng'),
                      subtitle: Text(_formatDateTime(_effectiveFrom)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: _selectEffectiveDate,
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      'Lưu ý: thay đổi chính sách không được tự động '
                          'làm mất hiệu lực các booking đã CONFIRMED. '
                          'Quy trình xử lý thay đổi cần được xác định rõ.',
                    ),
                  ],
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
                      'Tóm tắt chính sách',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildSummaryRow(
                      icon: Icons.calendar_month_outlined,
                      title: 'Đặt trước tối đa',
                      value: '${_daysController.text} ngày',
                    ),
                    _buildSummaryRow(
                      icon: Icons.access_time,
                      title: 'Báo trước tối thiểu',
                      value: '${_noticeHoursController.text} giờ',
                    ),
                    _buildSummaryRow(
                      icon: Icons.event_busy_outlined,
                      title: 'Hạn hủy lịch',
                      value: '${_cancelHoursController.text} giờ',
                    ),
                    _buildSummaryRow(
                      icon: Icons.event_available_outlined,
                      title: 'Số lịch tương lai tối đa',
                      value: '${_futureBookingsController.text} lịch',
                    ),
                    _buildSummaryRow(
                      icon: Icons.calendar_today_outlined,
                      title: 'Bắt đầu áp dụng',
                      value: _formatDateTime(_effectiveFrom),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_saveMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _saveMessage!.startsWith('Kiểm tra hợp lệ')
                      ? Colors.green.withValues(alpha: 0.10)
                      : Colors.orange.withValues(alpha: 0.10),
                ),
                child: Text(_saveMessage!),
              ),
              const SizedBox(height: 12),
            ],

            FilledButton.icon(
              onPressed: _savePolicy,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Kiểm tra và lưu chính sách'),
            ),
          ],
        ),
      ),
    );
  }
}
