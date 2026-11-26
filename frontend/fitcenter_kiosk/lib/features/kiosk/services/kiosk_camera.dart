import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

enum KioskCameraStatus { starting, ready, unavailable }

/// Camera dùng chung cho cả kiosk: mở một lần và giữ mở suốt vòng đời, để
/// preview luôn hiển thị và các lần check-in chỉ việc chụp ảnh từ camera đang
/// chạy. Mất camera hoặc lỗi thì tự mở lại sau [retryDelay].
class KioskCamera extends ChangeNotifier {
  KioskCamera({this.retryDelay = const Duration(seconds: 3)});

  final Duration retryDelay;

  CameraController? _controller;
  KioskCameraStatus _status = KioskCameraStatus.starting;
  Timer? _retryTimer;
  bool _disposed = false;
  bool _capturing = false;

  CameraController? get controller => _controller;

  KioskCameraStatus get status => _status;

  Future<void> start() async {
    if (_disposed) return;

    _retryTimer?.cancel();
    await _release();
    _setStatus(KioskCameraStatus.starting);

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Không tìm thấy camera.');
      }

      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (_disposed) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onControllerChanged);
      _controller = controller;
      _setStatus(KioskCameraStatus.ready);
    } catch (error) {
      debugPrint('Camera start failed: $error');
      _markUnavailable();
    }
  }

  /// Chụp [count] ảnh JPEG liên tiếp từ camera đang chạy. Ném lỗi nếu camera
  /// chưa sẵn sàng hoặc đang chụp; lỗi khi chụp sẽ kích hoạt mở lại camera.
  Future<List<Uint8List>> captureFrames({
    required int count,
    Duration interval = const Duration(milliseconds: 300),
  }) async {
    final controller = _controller;
    if (controller == null || _status != KioskCameraStatus.ready) {
      throw StateError('Camera chưa sẵn sàng.');
    }
    if (_capturing) {
      throw StateError('Camera đang chụp.');
    }

    _capturing = true;
    try {
      final frames = <Uint8List>[];
      for (var i = 0; i < count; i++) {
        final file = await controller.takePicture();
        frames.add(await file.readAsBytes());
        await _deleteTemporaryFile(file.path);

        if (i + 1 < count) {
          await Future.delayed(interval);
        }
      }
      return frames;
    } catch (error) {
      debugPrint('Frame capture failed: $error');
      _markUnavailable();
      rethrow;
    } finally {
      _capturing = false;
    }
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller != null && controller.value.hasError) {
      debugPrint('Camera error: ${controller.value.errorDescription}');
      _markUnavailable();
    }
  }

  void _markUnavailable() {
    if (_disposed) return;

    _setStatus(KioskCameraStatus.unavailable);
    unawaited(_release());

    _retryTimer?.cancel();
    _retryTimer = Timer(retryDelay, start);
  }

  Future<void> _release() async {
    final controller = _controller;
    if (controller == null) return;

    _controller = null;
    controller.removeListener(_onControllerChanged);
    notifyListeners();
    try {
      await controller.dispose();
    } catch (_) {
      // Camera đã mất thì dispose có thể lỗi; không còn gì để giải phóng.
    }
  }

  void _setStatus(KioskCameraStatus status) {
    if (_disposed || _status == status) return;
    _status = status;
    notifyListeners();
  }

  /// Ảnh khuôn mặt là dữ liệu sinh trắc học: không để lại trong bộ nhớ tạm.
  Future<void> _deleteTemporaryFile(String path) async {
    if (kIsWeb) return;
    try {
      await File(path).delete();
    } catch (_) {
      // Không xóa được thì bỏ qua; ảnh vẫn chỉ nằm trong thư mục tạm.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onControllerChanged);
    controller?.dispose();
    super.dispose();
  }
}
