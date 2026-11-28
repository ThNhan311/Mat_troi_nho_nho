import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/kiosk_capturing_screen.dart';
import '../services/core_client.dart';
import '../services/face_service_config.dart';
import '../services/kiosk_camera.dart';
import '../services/kiosk_enrollment_service.dart';
import '../widgets/kiosk_camera_preview.dart';

/// Đăng ký khuôn mặt: chỉ một nút. Khi nối backend, hội viên là người lễ tân
/// đã chọn ([request]); chạy độc lập thì mã tự tạo. Token Admin lấy từ cấu hình
/// build (FACE_ADMIN_TOKEN, chỉ dùng cho demo trên máy dev).
class EnrollmentPage extends StatefulWidget {
  const EnrollmentPage({
    super.key,
    required this.camera,
    this.request,
    this.core,
  }) : assert(request == null || core != null);

  final PendingEnrollment? request;
  final CoreClient? core;

  /// Camera dùng chung của kiosk: chỉ một nơi được mở camera cùng lúc.
  final KioskCamera camera;

  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  final KioskEnrollmentService _enrollmentService = KioskEnrollmentService();

  bool _isCapturing = false;
  bool _isLoading = false;
  bool _closing = false;
  Timer? _watchTimer;
  Timer? _closeTimer;
  String? _enrolledId;
  EnrollmentResult? _result;

  /// Mã tự tạo, ví dụ HV20261111-084512.
  String _newMemberId() {
    String two(int value) => value.toString().padLeft(2, '0');
    final now = DateTime.now();
    return 'HV${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  @override
  void initState() {
    super.initState();
    if (widget.request != null) {
      _watchTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _leaveIfWithdrawn(),
      );
    }
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }

  /// true khi yêu cầu này vẫn đang chờ; null khi chưa hỏi được backend.
  Future<bool?> _stillWanted() async {
    try {
      final pending = await widget.core!.pending();
      return pending?.requestId == widget.request!.requestId;
    } on CoreException catch (error) {
      debugPrint('Core check failed: $error');
      return null;
    }
  }

  /// Lễ tân hủy hoặc hết giờ chờ thì quay về màn hình quét.
  Future<void> _leaveIfWithdrawn() async {
    if (_isCapturing || _isLoading || _result != null) return;
    final wanted = await _stillWanted();
    if (wanted != false) return;
    if (!mounted || _isCapturing || _isLoading || _result != null) return;
    _close();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  Future<void> _report(EnrollmentResult result) async {
    final request = widget.request;
    if (request == null) return;
    _watchTimer?.cancel();
    try {
      await widget.core!.report(request.requestId, switch (result) {
        EnrollmentResult.success => 'SUCCESS',
        EnrollmentResult.duplicate => 'DUPLICATE',
        EnrollmentResult.failed => 'FAILED',
      });
    } on CoreException catch (error) {
      debugPrint('Core report failed: $error');
    }
    if (mounted) {
      _closeTimer = Timer(const Duration(seconds: 4), _close);
    }
  }

  Future<void> _enroll() async {
    if (_isCapturing || _isLoading) return;
    if (widget.request != null) {
      // Không chụp nếu lễ tân đã hủy, tránh lưu mặt cho yêu cầu cũ.
      setState(() => _isLoading = true);
      final wanted = await _stillWanted();
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (wanted == false) return _close();
    }
    final memberId = widget.request?.memberId ?? _newMemberId();

    setState(() {
      _enrolledId = memberId;
      _result = null;
      _isCapturing = true;
    });

    try {
      final frames = await widget.camera.captureFrames(
        count: 8,
        interval: const Duration(milliseconds: 600),
      );

      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _isLoading = true;
      });

      final result = await _enrollmentService.enroll(
        memberId: memberId,
        adminToken: FaceServiceConfig.adminToken,
        frames: frames,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
      await _report(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = EnrollmentResult.failed;
        _isCapturing = false;
        _isLoading = false;
      });
      await _report(EnrollmentResult.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          KioskCameraPreview(
            camera: widget.camera,
            dim: _isCapturing ? 0.15 : 0.5,
          ),
          if (_isCapturing)
            const KioskCapturingScreen()
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.request != null) ...[
                        Text(
                          widget.request!.memberName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_isLoading)
                        const CircularProgressIndicator(color: Colors.white)
                      else ...[
                        // Nối backend: mỗi yêu cầu chỉ chụp một lần.
                        if (widget.request == null || _result == null)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _enroll,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 28,
                                ),
                              ),
                              child: const Text(
                                'CHẠM ĐỂ ĐĂNG KÝ',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (_result != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            switch (_result!) {
                              EnrollmentResult.success =>
                                widget.request == null
                                    ? 'Đăng ký thành công\n$_enrolledId'
                                    : 'Đăng ký thành công',
                              EnrollmentResult.duplicate =>
                                'Khuôn mặt này đã được đăng ký rồi',
                              EnrollmentResult.failed =>
                                widget.request == null
                                    ? 'Chưa thành công, chạm để thử lại'
                                    : 'Chưa thành công, vui lòng báo lễ tân',
                            },
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _result == EnrollmentResult.success
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          // Do lễ tân yêu cầu thì màn hình tự quay về điểm danh.
          if (widget.request == null)
            Positioned(
              top: 8,
              left: 8,
              child: SafeArea(
                child: IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
