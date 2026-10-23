import 'package:flutter/material.dart';

class ConfirmedSessionsPage extends StatefulWidget {
  final void Function(Map<String, dynamic> session) onOpenSession;

  const ConfirmedSessionsPage({
    super.key,
    required this.onOpenSession,
  });

  @override
  State<ConfirmedSessionsPage> createState() =>
      _ConfirmedSessionsPageState();
}

class _ConfirmedSessionsPageState
    extends State<ConfirmedSessionsPage> {
  final List<Map<String, dynamic>> _sessions = [
    {
      'id': 'BK001',
      'memberName': 'Nguyễn Minh Anh',
      'date': DateTime(2026, 10, 24),
      'start': '08:00',
      'end': '09:30',
      'status': 'CONFIRMED',
    },
    {
      'id': 'BK002',
      'memberName': 'Trần Hoàng Long',
      'date': DateTime(2026, 10, 24),
      'start': '10:00',
      'end': '11:30',
      'status': 'CONFIRMED',
    },
    {
      'id': 'BK003',
      'memberName': 'Lê Ngọc Hà',
      'date': DateTime(2026, 10, 25),
      'start': '14:00',
      'end': '15:30',
      'status': 'CONFIRMED',
    },
  ];

  String _selectedFilter = 'Tất cả';

  final List<String> _filters = [
    'Tất cả',
    'Hôm nay',
    'Sắp tới',
  ];

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  int _minutesFromTime(String value) {
    final parts = value.split(':');

    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  DateTime _sessionStartDateTime(
      Map<String, dynamic> session,
      ) {
    final date = session['date'] as DateTime;
    final time = (session['start'] as String).split(':');

    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(time[0]),
      int.parse(time[1]),
    );
  }

  DateTime _sessionEndDateTime(
      Map<String, dynamic> session,
      ) {
    final date = session['date'] as DateTime;
    final time = (session['end'] as String).split(':');

    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(time[0]),
      int.parse(time[1]),
    );
  }

  List<Map<String, dynamic>> get _filteredSessions {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final sessions = _sessions.where((session) {
      final sessionDate = session['date'] as DateTime;

      if (session['status'] != 'CONFIRMED') {
        return false;
      }

      if (_selectedFilter == 'Hôm nay') {
        return sessionDate.year == today.year &&
            sessionDate.month == today.month &&
            sessionDate.day == today.day;
      }

      if (_selectedFilter == 'Sắp tới') {
        return _sessionStartDateTime(session).isAfter(now);
      }

      return true;
    }).toList();

    sessions.sort((a, b) {
      final dateA = _sessionStartDateTime(a);
      final dateB = _sessionStartDateTime(b);

      return dateA.compareTo(dateB);
    });

    return sessions;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sessions = _filteredSessions;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_note,
                  size: 32,
                  color: colors.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buổi tập đã xác nhận',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('Theo dõi lịch tập với học viên'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tổng số buổi tập đã xác nhận.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 40,
                    color: colors.onPrimary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_sessions.where((s) => s['status'] == 'CONFIRMED').length} buổi tập',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trong danh sách dữ liệu mẫu',
                          style: TextStyle(
                            color: colors.onPrimary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Lọc lịch tập',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              children: _filters.map((filter) {
                return ChoiceChip(
                  label: Text(filter),
                  selected: _selectedFilter == filter,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Danh sách buổi tập',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${sessions.length} buổi',
                  style: TextStyle(
                    color: colors.onSurface.withValues(
                      alpha: 0.65,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (sessions.isEmpty)
              _buildEmptyState(context)
            else
              ...sessions.map(
                    (session) => _buildSessionCard(
                  context,
                  session,
                ),
              ),

            const SizedBox(height: 16),

            Text(
              'Dữ liệu hiện là dữ liệu mẫu, chưa lấy từ backend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
      BuildContext context,
      Map<String, dynamic> session,
      ) {
    final colors = Theme.of(context).colorScheme;
    final date = session['date'] as DateTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onOpenSession(session),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colors.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      session['memberName'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),

              const SizedBox(height: 16),

              _buildInfoRow(
                context,
                Icons.calendar_today,
                _formatDate(date),
              ),

              const SizedBox(height: 10),

              _buildInfoRow(
                context,
                Icons.access_time,
                '${session['start']} - ${session['end']}',
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 15,
                          color: Colors.green,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Đã xác nhận',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Chi tiết',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context,
      IconData icon,
      String text,
      ) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: colors.onSurface.withValues(alpha: 0.65),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),
          const Text(
            'Không có buổi tập nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Không tìm thấy buổi tập phù hợp với bộ lọc.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}