import 'package:flutter/material.dart';

import '../services/kiosk_enrollment_service.dart';

class EnrollmentPage extends StatefulWidget {
  const EnrollmentPage({super.key});

  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  final KioskEnrollmentService _enrollmentService =
  KioskEnrollmentService();

  bool _isLoading = false;
  EnrollmentResult? _result;

  Future<void> _startEnrollment() async {
    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final result = await _enrollmentService.enroll();

      if (!mounted) return;

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _result = EnrollmentResult.failed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.face_retouching_natural,
                color: Colors.white,
                size: 96,
              ),
              const SizedBox(height: 24),
              const Text(
                'Đăng ký khuôn mặt',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Đang xử lý đăng ký...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                      ),
                    ),
                  ],
                )
              else if (_result == EnrollmentResult.success)
                const Text(
                  'Đăng ký thành công',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 24,
                  ),
                )
              else if (_result == EnrollmentResult.failed)
                  const Text(
                    'Đăng ký chưa thành công. Vui lòng thử lại.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 22,
                    ),
                  )
                else
                  const Text(
                    'Vui lòng chuẩn bị để đăng ký khuôn mặt.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                    ),
                  ),
              const SizedBox(height: 28),
              if (!_isLoading)
                ElevatedButton(
                  onPressed: _startEnrollment,
                  child: Text(
                    _result == null ? 'Bắt đầu đăng ký' : 'Thử lại',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Quay lại',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}