import 'package:flutter/material.dart';

class ActivityRecordsPage extends StatefulWidget {
  const ActivityRecordsPage({super.key});

  @override
  State<ActivityRecordsPage> createState() =>
      _ActivityRecordsPageState();
}

class _ActivityRecordsPageState extends State<ActivityRecordsPage> {
  String _selectedType = 'Tất cả';
  String _selectedStatus = 'Tất cả';
  String _searchQuery = '';

  final TextEditingController _searchController =
  TextEditingController();

  final List<Map<String, String>> _records = [
    {
      'type': 'Booking',
      'id': 'BK001',
      'description': 'Lịch tập với PT Nguyễn Minh Anh',
      'time': '08:30 - 24/10/2026',
      'status': 'Đã xác nhận',
    },
    {
      'type': 'Payment',
      'id': 'PAY001',
      'description': 'Thanh toán gói tập 1 tháng',
      'time': '09:15 - 24/10/2026',
      'status': 'Thành công',
    },
    {
      'type': 'Attendance',
      'id': 'AT001',
      'description': 'Hội viên check-in tại trung tâm',
      'time': '10:00 - 24/10/2026',
      'status': 'Đã ghi nhận',
    },
    {
      'type': 'Booking',
      'id': 'BK002',
      'description': 'Lịch tập với PT Trần Quốc Bảo',
      'time': '14:00 - 24/10/2026',
      'status': 'Đã xác nhận',
    },
    {
      'type': 'Payment',
      'id': 'PAY002',
      'description': 'Gia hạn gói tập',
      'time': '15:20 - 24/10/2026',
      'status': 'Thành công',
    },
    {
      'type': 'Booking',
      'id': 'BK003',
      'description': 'Lịch tập với PT Lê Hoàng Nam',
      'time': '16:30 - 24/10/2026',
      'status': 'Đã hủy',
    },
    {
      'type': 'Payment',
      'id': 'PAY003',
      'description': 'Thanh toán gói tập 3 tháng',
      'time': '17:00 - 24/10/2026',
      'status': 'Đang chờ',
    },
    {
      'type': 'Attendance',
      'id': 'AT002',
      'description': 'Hội viên check-out tại trung tâm',
      'time': '18:00 - 24/10/2026',
      'status': 'Đã ghi nhận',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filteredRecords {
    return _records.where((record) {
      final matchesType = _selectedType == 'Tất cả' ||
          record['type'] == _selectedType;

      final matchesStatus = _selectedStatus == 'Tất cả' ||
          record['status'] == _selectedStatus;

      final query = _searchQuery.trim().toLowerCase();

      final matchesSearch = query.isEmpty ||
          record['id']!.toLowerCase().contains(query) ||
          record['description']!.toLowerCase().contains(query) ||
          record['type']!.toLowerCase().contains(query) ||
          record['status']!.toLowerCase().contains(query);

      return matchesType && matchesStatus && matchesSearch;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _selectedType = 'Tất cả';
      _selectedStatus = 'Tất cả';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredRecords = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ vận hành'),
        actions: [
          IconButton(
            tooltip: 'Đặt lại bộ lọc',
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hồ sơ vận hành',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Theo dõi hồ sơ đặt lịch, thanh toán và điểm danh của trung tâm.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context,
                  title: 'Đặt lịch',
                  count: _countByType('Booking'),
                  icon: Icons.calendar_month_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  title: 'Thanh toán',
                  count: _countByType('Payment'),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  title: 'Điểm danh',
                  count: _countByType('Attendance'),
                  icon: Icons.how_to_reg_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Tìm kiếm hồ sơ',
              hintText: 'Nhập mã hồ sơ hoặc nội dung',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                tooltip: 'Xóa tìm kiếm',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Loại hồ sơ',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Tất cả',
                child: Text('Tất cả hồ sơ'),
              ),
              DropdownMenuItem(
                value: 'Booking',
                child: Text('Booking - Đặt lịch'),
              ),
              DropdownMenuItem(
                value: 'Payment',
                child: Text('Payment - Thanh toán'),
              ),
              DropdownMenuItem(
                value: 'Attendance',
                child: Text('Attendance - Điểm danh'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedType = value;
                });
              }
            },
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Trạng thái',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.filter_alt_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Tất cả',
                child: Text('Tất cả trạng thái'),
              ),
              DropdownMenuItem(
                value: 'Đã xác nhận',
                child: Text('Đã xác nhận'),
              ),
              DropdownMenuItem(
                value: 'Thành công',
                child: Text('Thành công'),
              ),
              DropdownMenuItem(
                value: 'Đã ghi nhận',
                child: Text('Đã ghi nhận'),
              ),
              DropdownMenuItem(
                value: 'Đã hủy',
                child: Text('Đã hủy'),
              ),
              DropdownMenuItem(
                value: 'Đang chờ',
                child: Text('Đang chờ'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedStatus = value;
                });
              }
            },
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Danh sách hồ sơ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${filteredRecords.length} bản ghi',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (filteredRecords.isEmpty)
            _buildEmptyState(context)
          else
            ...filteredRecords.map(
                  (record) => _buildRecordCard(context, record),
            ),

          const SizedBox(height: 16),
          Text(
            'Lưu ý: Đây là dữ liệu minh họa. '
                'Các bản ghi chưa được lấy từ máy chủ.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  int _countByType(String type) {
    return _records.where((record) => record['type'] == type).length;
  }

  Widget _buildSummaryCard(
      BuildContext context, {
        required String title,
        required int count,
        required IconData icon,
      }) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 14,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 25,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(
      BuildContext context,
      Map<String, String> record,
      ) {
    final theme = Theme.of(context);
    final type = record['type']!;
    final status = record['status']!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    _getIcon(type),
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record['description']!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_getTypeLabel(type)} • ${record['id']}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.access_time,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record['time']!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Trạng thái:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 32,
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy hồ sơ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Thử thay đổi từ khóa hoặc bộ lọc để xem kết quả khác.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Đặt lại bộ lọc'),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'Booking':
        return 'Đặt lịch';
      case 'Payment':
        return 'Thanh toán';
      case 'Attendance':
        return 'Điểm danh';
      default:
        return 'Hoạt động';
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'Booking':
        return Icons.calendar_month_outlined;
      case 'Payment':
        return Icons.payments_outlined;
      case 'Attendance':
        return Icons.how_to_reg_outlined;
      default:
        return Icons.history;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Thành công':
      case 'Đã ghi nhận':
        return Colors.green;
      case 'Đã xác nhận':
        return Colors.blue;
      case 'Đang chờ':
        return Colors.orange;
      case 'Đã hủy':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}