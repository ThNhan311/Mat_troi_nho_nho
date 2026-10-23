
import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final items = [
      {
        'question': 'Làm thế nào để tạo lịch rảnh?',
        'answer':
        'Mở mục Lịch rảnh, chọn ngày và khung giờ muốn mở cho hội viên đặt lịch. Kiểm tra thông tin trước khi lưu.',
      },
      {
        'question': 'Tôi có thể chỉnh sửa hoặc xóa lịch rảnh không?',
        'answer':
        'Bạn có thể chỉnh sửa hoặc xóa khung giờ chưa có hội viên đặt. Những khung giờ đã được đặt cần được xử lý theo trạng thái lịch hiện tại.',
      },
      {
        'question': 'Làm thế nào để xem các buổi tập đã được đặt?',
        'answer':
        'Mở mục Buổi tập để xem danh sách các buổi tập, thông tin hội viên và trạng thái xác nhận của từng buổi.',
      },
      {
        'question': 'Làm thế nào để hủy một buổi tập?',
        'answer':
        'Mở chi tiết buổi tập và chọn chức năng hủy. Bạn cần nhập lý do hủy trước khi xác nhận. Khung giờ đã hủy không tự động mở lại để đặt lịch.',
      },
      {
        'question': 'Khi nào tôi có thể hoàn thành buổi tập?',
        'answer':
        'Bạn chỉ có thể đánh dấu hoàn thành đối với buổi tập đang ở trạng thái Đã xác nhận. Sau khi hoàn thành, trạng thái buổi tập sẽ được cập nhật.',
      },
      {
        'question': 'Làm thế nào để tạo giáo án tập luyện?',
        'answer':
        'Mở mục Giáo án, tạo giáo án mới, nhập thông tin cần thiết và chọn hội viên được áp dụng giáo án.',
      },
      {
        'question': 'Dữ liệu có được lưu sau khi tắt ứng dụng không?',
        'answer':
        'Trong phiên bản demo, dữ liệu có thể chỉ được lưu trong bộ nhớ khi ứng dụng đang chạy. Dữ liệu có thể mất khi tắt ứng dụng. Khả năng lưu trữ lâu dài phụ thuộc vào việc tích hợp cơ sở dữ liệu.',
      },
    ];

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
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
              borderRadius: BorderRadius.circular(18),
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
                  'Tìm câu trả lời cho các câu hỏi thường gặp '
                      'khi sử dụng FitCenter dành cho huấn luyện viên.',
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
                borderRadius: BorderRadius.circular(14),
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
                    16,
                    0,
                    16,
                    16,
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
