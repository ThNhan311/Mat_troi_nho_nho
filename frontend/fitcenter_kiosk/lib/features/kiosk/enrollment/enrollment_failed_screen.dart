import 'package:flutter/material.dart';

class EnrollmentFailedScreen extends StatelessWidget {
  const EnrollmentFailedScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 88, color: Colors.orangeAccent),
          const SizedBox(height: 24),
          const Text(
            'Đăng ký chưa thành công',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vui lòng thử lại.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 20),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
