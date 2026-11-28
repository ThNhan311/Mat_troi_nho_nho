import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/booking_state.dart';

/// Pull down at the top of a page to reload it. This replaces reload buttons.
///
/// The page's own scroll view needs [AlwaysScrollableScrollPhysics]. Setting it
/// here would also reach selectable text, which would then steal the drag.
class PullToReload extends StatelessWidget {
  const PullToReload({super.key, required this.onReload, required this.child});

  /// Reloads bookings, trainers and slots unless something is already running.
  static Future<void> bookings(BookingState state) async {
    if (state.loading || state.busy) return;
    await state.refresh(manual: true);
  }

  final Future<void> Function() onReload;

  /// The page's scroll view.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: base.copyWith(
        // Mouse dragging lets the web pull to reload like a phone.
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      child: RefreshIndicator(onRefresh: onReload, child: child),
    );
  }
}
