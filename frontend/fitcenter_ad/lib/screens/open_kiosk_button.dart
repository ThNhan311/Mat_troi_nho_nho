import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/kiosk_desk_service.dart';

/// Opens the camera screen used for check-in and face capture.
class OpenKioskButton extends StatefulWidget {
  final KioskDeskService service;
  const OpenKioskButton({super.key, required this.service});
  @override
  State<OpenKioskButton> createState() => _OpenKioskButtonState();
}

class _OpenKioskButtonState extends State<OpenKioskButton> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      await widget.service.openScreen();
      message =
          'Đang mở màn hình check-in, đợi vài giây. Kéo cửa sổ sang màn hình '
          'có camera.';
    } on ApiError catch (e) {
      message = e.status == 503
          ? 'Máy chủ này chưa được cấu hình để mở màn hình check-in.'
          : e.toString();
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    key: const Key('open-kiosk'),
    onPressed: _busy ? null : _open,
    icon: const Icon(Icons.videocam_outlined, size: 20),
    label: const Text('Mở màn hình check-in'),
  );
}
