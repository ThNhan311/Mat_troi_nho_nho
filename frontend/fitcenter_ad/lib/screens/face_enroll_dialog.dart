import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/kiosk_desk_service.dart';

/// Built with --dart-define=FACE_KIOSK=true: faces are taken from the account
/// list on the camera screen.
const faceKioskEnabled = bool.fromEnvironment('FACE_KIOSK');

/// Face step of adding an account: the camera screen takes the pictures while
/// the front desk watches the result here. Closing while waiting cancels it.
class FaceEnrollDialog extends StatefulWidget {
  final KioskDeskService kiosk;
  final String profileId, name;
  final Duration pollEvery;
  const FaceEnrollDialog({
    super.key,
    required this.kiosk,
    required this.profileId,
    required this.name,
    this.pollEvery = const Duration(seconds: 2),
  });
  @override
  State<FaceEnrollDialog> createState() => _FaceEnrollDialogState();
}

class _FaceEnrollDialogState extends State<FaceEnrollDialog> {
  String? _requestId, _error;
  String _status = 'SENDING';
  bool _polling = false;
  Timer? _timer;
  late final int _epoch = widget.kiosk.api.sessionEpoch;
  bool get _current => mounted && widget.kiosk.api.sessionEpoch == _epoch;
  bool get _waiting => _status == 'SENDING' || _status == 'WAITING';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _timer?.cancel();
    setState(() {
      _status = 'SENDING';
      _error = null;
    });
    try {
      final request = await widget.kiosk.requestEnrollment(widget.profileId);
      if (!_current) return;
      setState(() {
        _requestId = request.requestId;
        _status = request.status;
      });
      _timer = Timer.periodic(widget.pollEvery, (_) => _poll());
    } on ApiError catch (e) {
      if (_current) {
        setState(() {
          _status = 'ERROR';
          _error = e.status == 404
              ? 'Máy chủ chưa bật kết nối màn hình camera.'
              : e.toString();
        });
      }
    }
  }

  Future<void> _poll() async {
    if (_polling || !_current || !_waiting) return;
    _polling = true;
    try {
      final latest = (await widget.kiosk.read()).enrollment;
      if (!_current) return;
      setState(() {
        _error = null;
        _status = latest?.requestId == _requestId ? latest!.status : 'REPLACED';
      });
      if (!_waiting) _timer?.cancel();
    } on ApiError catch (e) {
      if (_current) setState(() => _error = e.toString());
    } finally {
      _polling = false;
    }
  }

  Future<void> _close() async {
    _timer?.cancel();
    final navigator = Navigator.of(context);
    if (_status == 'WAITING') {
      try {
        await widget.kiosk.cancel();
      } on ApiError {
        // The request expires by itself.
      }
    }
    if (mounted) navigator.pop(_status == 'SUCCESS');
  }

  @override
  Widget build(BuildContext context) {
    final text = switch (_status) {
      'SENDING' => 'Đang gọi màn hình camera...',
      'WAITING' =>
        'Mời ${widget.name} nhìn vào màn hình camera và chạm "CHẠM ĐỂ ĐĂNG KÝ".',
      'SUCCESS' => 'Đã lưu khuôn mặt của ${widget.name}.',
      'DUPLICATE' => 'Khuôn mặt này đã được đăng ký cho người khác.',
      'FAILED' => 'Chưa lưu được khuôn mặt.',
      'EXPIRED' => 'Hết thời gian chờ chụp.',
      'ERROR' => 'Chưa gửi được yêu cầu chụp.',
      _ => 'Yêu cầu chụp đã bị hủy hoặc thay thế.',
    };
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Khuôn mặt: ${widget.name}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_waiting)
                const CircularProgressIndicator()
              else
                Icon(
                  _status == 'SUCCESS'
                      ? Icons.check_circle
                      : Icons.error_outline,
                  size: 48,
                  color: _status == 'SUCCESS' ? Colors.green : Colors.orange,
                ),
              const SizedBox(height: 16),
              Text(text, textAlign: TextAlign.center),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!_waiting && _status != 'SUCCESS')
            TextButton(onPressed: _start, child: const Text('Chụp lại')),
          FilledButton(
            key: const Key('face-close'),
            onPressed: _close,
            child: Text(_status == 'SUCCESS' ? 'Xong' : 'Bỏ qua'),
          ),
        ],
      ),
    );
  }
}
