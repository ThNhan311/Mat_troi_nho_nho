import 'package:flutter/material.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Bạn có lịch tập mới!',
      'message':
      'Một hội viên đã đặt lịch tập với bạn. Hãy kiểm tra danh sách buổi tập để xem chi tiết.',
      'time': 'Hôm nay',
      'icon': Icons.event_available,
      'isRead': false,
    },
    {
      'title': 'Đừng quên kiểm tra lịch rảnh',
      'message':
      'Cập nhật các khung giờ rảnh để hội viên có thể đặt lịch tập với bạn.',
      'time': 'Hôm qua',
      'icon': Icons.calendar_month,
      'isRead': false,
    },
    {
      'title': 'Hoàn thiện giáo án tập luyện',
      'message':
      'Hãy tạo hoặc cập nhật giáo án phù hợp với mục tiêu tập luyện của hội viên.',
      'time': 'Gần đây',
      'icon': Icons.fitness_center,
      'isRead': true,
    },
    {
      'title': 'Nhắc nhở hoàn thành buổi tập',
      'message':
      'Kiểm tra các buổi tập đã xác nhận và cập nhật trạng thái sau khi hoàn thành.',
      'time': 'Gần đây',
      'icon': Icons.check_circle_outline,
      'isRead': true,
    },
  ];

  int get _unreadCount =>
      _notifications.where((item) => item['isRead'] == false).length;

  void _markAsRead(int index) {
    setState(() {
      _notifications[index]['isRead'] = true;
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (final item in _notifications) {
        item['isRead'] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đánh dấu tất cả thông báo là đã đọc.'),
      ),
    );
  }

  void _showNotification(int index) {
    final item = _notifications[index];

    _markAsRead(index);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          icon: Icon(
            item['icon'] as IconData,
            color: colors.primary,
            size: 32,
          ),
          title: Text(item['title'] as String),
          content: Text(item['message'] as String),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        iconTheme: IconThemeData(color: colors.onSurface),
        title: Text(
          'Thông báo',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Đọc tất cả'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _unreadCount == 0
                          ? 'Bạn đã đọc tất cả thông báo.'
                          : 'Bạn có $_unreadCount thông báo chưa đọc.',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _notifications.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _notifications[index];
                final isRead = item['isRead'] == true;

                return Material(
                  color: isRead
                      ? colors.surfaceContainerHighest
                      : colors.primaryContainer.withValues(
                    alpha: 0.65,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _showNotification(index),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['title'] as String,
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontWeight: isRead
                                              ? FontWeight.w600
                                              : FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 9,
                                        height: 9,
                                        margin:
                                        const EdgeInsets.only(
                                          top: 5,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['message'] as String,
                                  style: TextStyle(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      item['time'] as String,
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!isRead)
                                      Text(
                                        'Chưa đọc',
                                        style: TextStyle(
                                          color: colors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      Text(
                                        'Đã đọc',
                                        style: TextStyle(
                                          color: colors.onSurface
                                              .withValues(alpha: 0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Thông báo hiện là dữ liệu mẫu, chưa đồng bộ với backend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 56,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chưa có thông báo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Thông báo mới sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}