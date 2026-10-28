
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class KioskCapturingScreen extends StatefulWidget {
  const KioskCapturingScreen({super.key});

  @override
  State<KioskCapturingScreen> createState() =>
      _KioskCapturingScreenState();
}

class _KioskCapturingScreenState extends State<KioskCapturingScreen> {
  CameraController? _controller;
  String? _error;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('Không tìm thấy camera.');
      }

      final camera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _controller = controller;
      await controller.initialize();

      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể khởi tạo camera.';
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 480,
            height: 300,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _initializing
                ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
                : _error != null
                ? Center(
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
            )
                : controller != null &&
                controller.value.isInitialized
                ? CameraPreview(controller)
                : const SizedBox.shrink(),
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
