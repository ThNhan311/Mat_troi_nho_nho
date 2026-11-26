import 'package:flutter/material.dart';

class EnrollmentCapturingScreen extends StatelessWidget {
  const EnrollmentCapturingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.face_retouching_natural, size: 88, color: Colors.white),
          SizedBox(height: 24),
          CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'Đang thu thập ảnh khuôn mặt...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 26),
          ),
          SizedBox(height: 12),
          Text(
            'Vui lòng giữ khuôn mặt trong khung hình.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
