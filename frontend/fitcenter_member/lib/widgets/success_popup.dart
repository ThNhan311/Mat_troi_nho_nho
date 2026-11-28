import 'dart:async';

import 'package:flutter/material.dart';

import '../services/booking_state.dart';

/// Shows each success message as a notification that drops from the top, over
/// whatever page is open.
class SuccessPopupHost extends StatefulWidget {
  const SuccessPopupHost({super.key, required this.state, required this.child});

  final BookingState state;
  final Widget child;

  @override
  State<SuccessPopupHost> createState() => _SuccessPopupHostState();
}

class _SuccessPopupHostState extends State<SuccessPopupHost> {
  static const _shownFor = Duration(seconds: 4);

  OverlayEntry? _entry;
  Timer? _timer;
  String? _last;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
  }

  @override
  void didUpdateWidget(SuccessPopupHost old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_onState);
      widget.state.addListener(_onState);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    _hide();
    super.dispose();
  }

  void _onState() {
    final message = widget.state.message;
    // A new action clears the message first, so the same words show again.
    if (message == _last) return;
    _last = message;
    if (message != null && mounted && widget.state.alive) _show(message);
  }

  void _show(String message) {
    _hide();
    final entry = OverlayEntry(
      builder: (_) => _Popup(message: message, onClose: _hide),
    );
    _entry = entry;
    Overlay.of(context).insert(entry);
    _timer = Timer(_shownFor, _hide);
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    _entry = null;
    entry
      ?..remove()
      ..dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Popup extends StatelessWidget {
  const _Popup({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: -1, end: 0),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              builder: (_, offset, child) => FractionalTranslation(
                translation: Offset(0, offset),
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Material(
                  key: const Key('success'),
                  color: colors.surface,
                  elevation: 10,
                  shadowColor: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF2E9E44),
                          size: 34,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('success-close'),
                          tooltip: 'Đóng thông báo',
                          onPressed: onClose,
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
