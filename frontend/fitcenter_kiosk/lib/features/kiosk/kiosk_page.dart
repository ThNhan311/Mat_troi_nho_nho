import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'enrollment/enrollment_page.dart';
import 'kiosk_state.dart';
import 'screens/kiosk_idle_screen.dart';
import 'screens/kiosk_success_screen.dart';
import 'screens/kiosk_membership_invalid_screen.dart';
import 'screens/kiosk_no_match_screen.dart';
import 'screens/kiosk_sleeping_screen.dart';
import 'services/core_client.dart';
import 'services/face_service_client.dart';
import 'services/face_service_config.dart';
import 'services/kiosk_camera.dart';
import 'services/kiosk_checkin_service.dart';
import 'widgets/kiosk_camera_preview.dart';

class KioskPage extends StatefulWidget {
  const KioskPage({super.key});

  @override
  State<KioskPage> createState() => _KioskPageState();
}

class _KioskPageState extends State<KioskPage> {
  final CoreClient? _core = CoreClient.fromEnvironment();
  late final KioskCheckinService _checkinService = KioskCheckinService(
    core: _core,
  );
  String? _handledRequest;

  // Lỗi kết nối phải hiện để lễ tân biết; tự tắt khi gọi lại được.
  // Báo check-in thất bại: hiện 5 giây rồi tự mất, mỗi lượt đứng trước máy
  // chỉ báo một lần để không nhấp nháy liên tục.
  String? _notice;
  Timer? _noticeTimer;
  int _misses = 0;
  bool _noticeShown = false;

  void _showNotice(String text) {
    if (!mounted || _noticeShown) return;
    _noticeShown = true;
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  /// Người cũ đã đi (hoặc vừa xong một việc): lượt sau được báo lại.
  void _resetNotice() {
    _misses = 0;
    _noticeShown = false;
    _noticeTimer?.cancel();
    if (mounted && _notice != null) setState(() => _notice = null);
  }

  bool _faceDown = false;
  bool _coreDown = false;

  void _setFaceDown(bool down) {
    if (mounted && down != _faceDown) setState(() => _faceDown = down);
  }

  void _setCoreDown(bool down) {
    if (mounted && down != _coreDown) setState(() => _coreDown = down);
  }

  void _noteFailure(Object error) {
    // BUSY chỉ là dịch vụ đang bận một lượt khác, không phải mất kết nối.
    if (error is FaceServiceException && error.code != 'BUSY') {
      _setFaceDown(true);
    }
    if (error is CoreException) _setCoreDown(true);
  }

  final KioskCamera _camera = KioskCamera();

  KioskState _state = KioskState.idle;

  Timer? _idleTimer;
  Timer? _resultTimer;

  String _memberName = 'Nguyễn Văn A';
  int _retryCount = 0;

  // Sau khi check-in xong, chờ người đó rời khỏi camera mới nhận diện lại.
  bool _needsLeave = false;
  bool _enrolling = false;

  @override
  void initState() {
    super.initState();
    _camera.start();
    _resetIdleTimer();
    _watchForFace();
    if (_core != null) _watchForEnrollment();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _resultTimer?.cancel();
    _noticeTimer?.cancel();
    _camera.dispose();
    _core?.close();
    super.dispose();
  }

  /// Chờ lễ tân chọn hội viên bên web Admin rồi tự mở màn hình đăng ký.
  Future<void> _watchForEnrollment() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      // Hỏi cả khi đang check-in: người chưa đăng ký đứng trước máy làm màn
      // hình quét liên tục, nếu chờ lúc rảnh thì yêu cầu bị lỡ mãi.
      if (_enrolling) continue;

      try {
        // Xóa trước, để yêu cầu xóa cũ không xóa nhầm khuôn mặt vừa đăng ký.
        await _removeFaces();
        final request = await _core!.pending();
        _setCoreDown(false);
        if (!mounted || _enrolling) continue;
        if (request == null || request.requestId == _handledRequest) continue;
        _handledRequest = request.requestId;
        // Yêu cầu của lễ tân được ưu tiên: bỏ lượt check-in đang dở (các bước
        // của nó tự dừng khi thấy trạng thái đã đổi).
        _enrolling = true;
        _resultTimer?.cancel();
        _resetNotice();
        setState(() => _state = KioskState.idle);
        await _openEnrollment(request);
      } on CoreException catch (error) {
        debugPrint('Core poll failed: $error');
        _setCoreDown(true);
      }
    }
  }

  /// Kiosk không còn tự chuyển sang chế độ ngủ: check-in chạy tự động nên không
  /// ai phải chạm màn hình để đánh thức.
  void _resetIdleTimer() {
    _idleTimer?.cancel();
  }

  void _setStateAndResetTimer(KioskState state) {
    setState(() {
      _state = state;
    });

    _resetIdleTimer();
  }

  void _wakeKiosk() {
    _retryCount = 0;
    _setStateAndResetTimer(KioskState.idle);
  }

  /// Vòng lặp tự động: mỗi giây chụp một ảnh để xem có người trước camera
  /// không; có thì bắt đầu check-in. Không cần chạm màn hình.
  Future<void> _watchForFace() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      if (_state != KioskState.idle || _enrolling) continue;
      if (_camera.status != KioskCameraStatus.ready) continue;

      final bool present;
      try {
        final probe = await _camera.captureFrames(count: 1);
        if (!mounted || _state != KioskState.idle || _enrolling) continue;
        present = await _checkinService.isFacePresent(probe);
        _setFaceDown(false);
      } catch (error) {
        debugPrint('Face probe failed: $error');
        _noteFailure(error);
        continue;
      }

      if (!present) {
        _needsLeave = false;
        // Giữ dòng đang hiện cho hết giờ, chỉ cho phép báo lại lượt sau.
        _misses = 0;
        _noticeShown = false;
        continue;
      }
      if (_needsLeave) continue;

      await _startCheckIn();
    }
  }

  Future<void> _removeFaces() async {
    final ids = await _core!.removals();
    if (ids.isEmpty) return;
    final face = FaceServiceClient();
    try {
      for (final id in ids) {
        await face.remove(
          memberId: id,
          adminToken: FaceServiceConfig.adminToken,
        );
        await _core.removalDone(id);
      }
    } on FaceServiceException catch (error) {
      debugPrint('Face removal failed: $error');
    } finally {
      face.close();
    }
  }

  Future<void> _openEnrollment([PendingEnrollment? request]) async {
    _enrolling = true;
    _resultTimer?.cancel();

    // Không hiệu ứng chuyển trang: với người đứng trước máy vẫn là một màn hình
    // camera, chỉ đổi từ điểm danh sang đăng ký.
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => EnrollmentPage(
          camera: _camera,
          request: request,
          core: request == null ? null : _core,
        ),
      ),
    );

    // Màn hình vừa đăng ký xong thường vẫn có người đứng trước camera.
    if (request != null) _needsLeave = true;
    _enrolling = false;
    if (mounted) _wakeKiosk();
  }

  Future<void> _startCheckIn() async {
    _idleTimer?.cancel();
    _resultTimer?.cancel();

    setState(() {
      _state = KioskState.capturing;
    });

    // Chụp từ camera đang mở sẵn; camera không bị đóng giữa các lần check-in.
    final List<Uint8List> frames;
    try {
      frames = await _camera.captureFrames(count: 3);
    } catch (_) {
      _onCaptureFailed();
      return;
    }

    await _onFramesCaptured(frames);
  }

  void _onCaptureFailed() {
    debugPrint('Camera capture failed');
    if (!mounted || _state != KioskState.capturing) return;

    _wakeKiosk();
  }

  Future<void> _onFramesCaptured(List<Uint8List> frames) async {
    if (!mounted || _state != KioskState.capturing) return;

    setState(() {
      _state = KioskState.recognizing;
    });

    try {
      final response = await _checkinService.checkIn(frames);

      if (!mounted || _state != KioskState.recognizing) return;

      switch (response.result) {
        case CheckInResult.success:
          _needsLeave = true;
          _resetNotice();
          setState(() {
            _state = KioskState.success;
            _memberName = response.memberName ?? 'Hội viên';
          });
          break;

        // Không check-in được thì camera giữ nguyên, chỉ báo một dòng ngắn.
        case CheckInResult.membershipInvalid:
          _needsLeave = true;
          _wakeKiosk();
          _showNotice(
            'Check-in thất bại: gói tập không còn hiệu lực. '
            'Vui lòng liên hệ lễ tân.',
          );
          return;

        case CheckInResult.noMatch:
          _wakeKiosk();
          // Lượt đầu có thể chụp lúc người còn đang bước tới, chưa báo vội.
          if (++_misses >= 2) {
            _showNotice('Check-in thất bại: không nhận diện được khuôn mặt.');
          }
          return;
      }
    } catch (error) {
      debugPrint('Check-in failed: $error');
      _noteFailure(error);
      if (!mounted || _state != KioskState.recognizing) return;

      _wakeKiosk();
      return;
    }

    _startResultTimer();
  }

  void _startResultTimer() {
    _resultTimer?.cancel();

    _resultTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _wakeKiosk();
    });
  }

  void _retryCheckIn() {
    _retryCount++;

    if (_retryCount > 3) {
      _wakeKiosk();
      return;
    }

    _startCheckIn();
  }

  void _showTestMenu() {
    _idleTimer?.cancel();
    _resultTimer?.cancel();

    showMenu<KioskState>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 40, 8, 0),
      items: const [
        PopupMenuItem(
          value: KioskState.idle,
          child: Text('Idle - Màn hình chờ'),
        ),
        PopupMenuItem(
          value: KioskState.capturing,
          child: Text('Capturing - Đang chụp ảnh'),
        ),
        PopupMenuItem(
          value: KioskState.recognizing,
          child: Text('Recognizing - Đang xác minh'),
        ),
        PopupMenuItem(
          value: KioskState.success,
          child: Text('Success - Thành công'),
        ),
        PopupMenuItem(
          value: KioskState.membershipInvalid,
          child: Text('Membership invalid'),
        ),
        PopupMenuItem(
          value: KioskState.noMatch,
          child: Text('No match - Không nhận diện'),
        ),
        PopupMenuItem(
          value: KioskState.sleeping,
          child: Text('Sleeping - Chế độ chờ'),
        ),
      ],
    ).then((selectedState) {
      if (!mounted || selectedState == null) return;

      setState(() {
        _state = selectedState;

        if (selectedState == KioskState.success) {
          _memberName = 'Nguyễn Văn A';
        }
      });

      _resetIdleTimer();
    });
  }

  Widget _buildCurrentScreen() {
    switch (_state) {
      case KioskState.idle:
        // Check-in tự động khi có người đứng trước camera, không cần chạm.
        return KioskIdleScreen(onTap: () {});

      case KioskState.sleeping:
        return KioskSleepingScreen(onWake: _wakeKiosk);

      // Đang quét cũng giữ màn hình chờ, chỉ đổi khi check-in thành công.
      case KioskState.capturing:
      case KioskState.recognizing:
        return KioskIdleScreen(onTap: () {});

      case KioskState.success:
        return KioskSuccessScreen(memberName: _memberName);

      case KioskState.membershipInvalid:
        return const KioskMembershipInvalidScreen();

      case KioskState.noMatch:
        return KioskNoMatchScreen(onRetry: _retryCheckIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera luôn mở: preview là nền của mọi màn hình trừ chế độ ngủ.
          if (_state != KioskState.sleeping)
            Positioned.fill(
              child: KioskCameraPreview(camera: _camera, dim: 0.55),
            ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _resetIdleTimer,
              child: _buildCurrentScreen(),
            ),
          ),
          // Vẫn hiện trong lúc kiosk quét ngầm, chỉ nhường chỗ cho kết quả
          // thành công.
          if (_notice != null && _state != KioskState.success)
            Positioned(
              top: 110,
              left: 24,
              right: 24,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Text(
                      _notice!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 22),
                    ),
                  ),
                ),
              ),
            ),
          if (_state != KioskState.sleeping)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: ListenableBuilder(
                listenable: _camera,
                builder: (context, _) {
                  final problems = [
                    if (_camera.status != KioskCameraStatus.ready)
                      'Camera chưa sẵn sàng, đang thử lại...',
                    if (_faceDown) 'Lỗi kết nối dịch vụ nhận diện khuôn mặt, đang thử lại...',
                    if (_coreDown) 'Lỗi kết nối máy chủ, đang thử lại...',
                  ];
                  if (problems.isEmpty) return const SizedBox.shrink();
                  return Text(
                    problems.join('\n'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 18,
                    ),
                  );
                },
              ),
            ),
          // Nối backend thì đăng ký bắt đầu từ lễ tân, màn hình quét không có nút.
          if (_core == null)
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _openEnrollment,
                      icon: const Icon(
                        Icons.person_add_alt_1,
                        color: Colors.white,
                        size: 26,
                      ),
                      label: const Text(
                        'Đăng ký khuôn mặt',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Menu kiểm thử',
                      onPressed: _showTestMenu,
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
