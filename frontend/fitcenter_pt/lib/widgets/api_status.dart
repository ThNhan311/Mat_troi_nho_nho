import 'package:flutter/material.dart';

import '../services/booking_state.dart';

class ApiStatus extends StatelessWidget {
  final BookingState state;
  const ApiStatus({super.key, required this.state});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Text('Giờ Việt Nam (UTC+07:00)'),
          const Spacer(),
          IconButton(
            key: const Key('refresh'),
            tooltip: 'Tải lại',
            onPressed: state.loading || state.busy
                ? null
                : () => state.refresh(manual: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (state.loading) const LinearProgressIndicator(),
      if (state.error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            state.error!,
            key: const Key('api-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (state.message != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(state.message!, key: const Key('success')),
        ),
      if (state.needsReconciliation)
        const Text(
          'Kết quả chưa rõ. Tải lại và kiểm tra lịch trước khi thử lại.',
        ),
    ],
  );
}

class UnavailablePage extends StatelessWidget {
  final String title;
  const UnavailablePage({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            const Icon(Icons.hourglass_empty, size: 48),
            const SizedBox(height: 12),
            const Text('Chưa khả dụng'),
          ],
        ),
      ),
    ),
  );
}
