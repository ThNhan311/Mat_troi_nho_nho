import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/kiosk_camera.dart';

/// Preview camera toàn màn hình, lật gương như gương soi. [dim] làm tối nền để
/// chữ của các màn hình phủ lên vẫn dễ đọc.
class KioskCameraPreview extends StatelessWidget {
  const KioskCameraPreview({super.key, required this.camera, this.dim = 0.55});

  final KioskCamera camera;
  final double dim;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: camera,
      builder: (context, _) {
        final controller = camera.controller;
        if (camera.status != KioskCameraStatus.ready ||
            controller == null ||
            !controller.value.isInitialized) {
          return const SizedBox.expand();
        }

        final ratio = controller.value.aspectRatio;

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 100 * ratio,
                  height: 100,
                  // camera_windows đã tự lật gương hình xem trước; lật thêm
                  // lần nữa ở đây sẽ thành ngược gương.
                  child: CameraPreview(controller),
                ),
              ),
            ),
            ColoredBox(color: Colors.black.withValues(alpha: dim)),
          ],
        );
      },
    );
  }
}
