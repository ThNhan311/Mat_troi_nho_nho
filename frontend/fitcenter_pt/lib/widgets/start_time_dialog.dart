import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';

import '../services/vietnam_time.dart';

/// Minutes are offered in steps of this many.
const _step = 5;

String twoDigits(int value) => value.toString().padLeft(2, '0');

/// The instant of a Vietnam wall-clock time on a Vietnam calendar day.
DateTime slotInstant(DateTime day, TimeOfDay time) => parseVietnamInput(
  '${day.year.toString().padLeft(4, '0')}-${twoDigits(day.month)}-'
  '${twoDigits(day.day)} ${twoDigits(time.hour)}:${twoDigits(time.minute)}',
);

/// A session can only start after this moment.
bool startsLater(DateTime day, TimeOfDay time) =>
    slotInstant(day, time).isAfter(DateTime.now().toUtc());

/// A 24 hour wheel picker that offers only times still ahead on the chosen day.
/// [keep] is an existing slot's own time, offered even off the five minute grid.
class StartTimeDialog extends StatefulWidget {
  const StartTimeDialog({super.key, required this.day, this.keep});

  final DateTime day;
  final TimeOfDay? keep;

  @override
  State<StartTimeDialog> createState() => _StartTimeDialogState();
}

class _StartTimeDialogState extends State<StartTimeDialog> {
  int? _hour, _minute;
  String? _error;

  List<int> _minutesOf(int hour) {
    final minutes = {
      for (var m = 0; m < 60; m += _step) m,
      if (widget.keep?.hour == hour) widget.keep!.minute,
    }.toList()..sort();
    return [
      for (final m in minutes)
        if (startsLater(widget.day, TimeOfDay(hour: hour, minute: m))) m,
    ];
  }

  List<int> get _hours => [
    for (var h = 0; h < 24; h++)
      if (_minutesOf(h).isNotEmpty) h,
  ];

  @override
  void initState() {
    super.initState();
    final hours = _hours;
    if (hours.isEmpty) return;
    // The existing time, else 08:00, else the first one still ahead.
    final wanted = widget.keep?.hour ?? 8;
    _hour = hours.contains(wanted) ? wanted : hours.first;
    final minutes = _minutesOf(_hour!);
    final keep = widget.keep?.minute;
    _minute = minutes.contains(keep) ? keep : minutes.first;
  }

  void _confirm(int hour, int minute) {
    final time = TimeOfDay(hour: hour, minute: minute);
    // The clock moves on while the dialog is open.
    if (!startsLater(widget.day, time)) {
      setState(() => _error = 'Giờ này vừa trôi qua. Hãy chọn giờ khác.');
      return;
    }
    Navigator.pop(context, time);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hours = _hours;
    final hour = hours.contains(_hour) ? _hour : hours.firstOrNull;
    final minutes = hour == null ? const <int>[] : _minutesOf(hour);
    final minute = minutes.contains(_minute) ? _minute : minutes.firstOrNull;
    return AlertDialog(
      title: const Text('Giờ bắt đầu', textAlign: TextAlign.center),
      content: SizedBox(
        width: 300,
        child: hour == null || minute == null
            ? const Text(
                'Hôm nay không còn giờ nào để đặt. Hãy chọn ngày khác.',
                textAlign: TextAlign.center,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // One band marks the chosen row of both wheels.
                        Container(
                          height: TimeWheel.rowHeight,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TimeWheel(
                                key: const Key('hour-wheel'),
                                values: hours,
                                selected: hour,
                                onChanged: (value) => setState(() {
                                  _hour = value;
                                  _minute = minute;
                                  _error = null;
                                }),
                              ),
                            ),
                            const Text(
                              ':',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Expanded(
                              child: TimeWheel(
                                key: const Key('minute-wheel'),
                                values: minutes,
                                selected: minute,
                                onChanged: (value) => setState(() {
                                  _hour = hour;
                                  _minute = value;
                                  _error = null;
                                }),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        if (hour != null && minute != null)
          FilledButton(
            key: const Key('time-confirm'),
            onPressed: () => _confirm(hour, minute),
            child: const Text('Chọn'),
          ),
      ],
    );
  }
}

/// One scrolling column of numbers.
class TimeWheel extends StatefulWidget {
  const TimeWheel({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  static const rowHeight = 44.0;

  final List<int> values;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.values.indexOf(widget.selected),
  );

  @override
  void didUpdateWidget(TimeWheel old) {
    super.didUpdateWidget(old);
    // Another hour can offer other minutes: keep the same number in the band.
    final index = widget.values.indexOf(widget.selected);
    if (old.values.length != widget.values.length ||
        old.values.firstOrNull != widget.values.firstOrNull) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToItem(index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ScrollConfiguration(
      // A mouse can drag the wheel too, as in the browser.
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
        scrollbars: false,
      ),
      child: CupertinoPicker(
        scrollController: _controller,
        itemExtent: TimeWheel.rowHeight,
        diameterRatio: 1.4,
        useMagnifier: true,
        magnification: 1.08,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (index) {
          if (index >= 0 && index < widget.values.length) {
            widget.onChanged(widget.values[index]);
          }
        },
        children: [
          for (final value in widget.values)
            Center(
              child: Text(
                twoDigits(value),
                style: TextStyle(
                  color: colors.onSurface,
                  fontFamily: 'Roboto',
                  fontSize: 24,
                  fontWeight: value == widget.selected
                      ? FontWeight.w800
                      : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
