import 'package:flutter/material.dart';

/// Lớp phủ khi đang chụp ảnh. Camera chạy nền ở KioskPage nên màn này chỉ vẽ
/// khung căn mặt và lời nhắc, không tự mở hay đóng camera.
class KioskCapturingScreen extends StatelessWidget {
  const KioskCapturingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 240,
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(160),
              border: Border.all(color: Colors.white, width: 4),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Đang chụp ảnh...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
