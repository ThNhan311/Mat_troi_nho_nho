
import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final items = [
      {
        'question': 'Làm thế nào để đặt lịch tập?',
        'answer':
        'Mở mục Lịch tập, chọn lịch phù hợp và thực hiện thao tác đặt lịch theo hướng dẫn trên màn hình.',
      },
      {
        'question': 'Làm thế nào để theo dõi bài tập?',
        'answer':
        'Mở Kế hoạch tập luyện, chọn ngày tập và đánh dấu vào từng bài sau khi hoàn thành.',
      },
      {
        'question': 'Xem lịch sử tập luyện ở đâu?',
        'answer':
        'Vào Cá nhân → Lịch sử tập luyện để xem tiến độ các buổi tập đã được ghi nhận.',
      },
      {
        'question': 'Làm thế nào để xem gói hội viên?',
        'answer':
        'Vào mục Gói hội viên để xem thông tin gói và các lựa chọn gia hạn hiện có.',
      },
      {
        'question': 'Dữ liệu có được lưu sau khi tắt ứng dụng không?',
        'answer':
        'Một số dữ liệu trong phiên bản hiện tại chỉ lưu trong bộ nhớ khi ứng dụng đang chạy. Dữ liệu có thể mất khi tắt hẳn ứng dụng.',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        iconTheme: IconThemeData(color: colors.onSurface),
        title: Text(
          'Trợ giúp',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.support_agent,
                  color: colors.primary,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bạn cần hỗ trợ?',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tìm câu trả lời cho những câu hỏi thường gặp về FitCenter.',
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Câu hỏi thường gặp',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
                (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  iconColor: colors.primary,
                  collapsedIconColor: colors.primary,
                  title: Text(
                    item['question']!,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    16, 0, 16, 16,
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item['answer']!,
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
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
}
