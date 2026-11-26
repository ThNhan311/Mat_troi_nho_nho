import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/report_service.dart';
import 'table_style.dart';

/// A day window relative to today (Vietnam time); both ends are included.
class DayRange {
  final String label;
  final int fromOffset, toOffset;
  const DayRange(this.label, this.fromOffset, this.toOffset);
}

const scheduleRanges = [
  DayRange('Hôm nay', 0, 0),
  DayRange('7 ngày tới', 0, 6),
  DayRange('30 ngày tới', 0, 29),
  DayRange('30 ngày qua', -29, 0),
];

/// Every trainer's and member's sessions in one place.
class SchedulePage extends StatelessWidget {
  final ReportService service;
  const SchedulePage({super.key, required this.service});

  @override
  Widget build(BuildContext context) => _ReportPage<TrainingSession>(
    title: 'Lịch tập',
    api: service.api,
    ranges: scheduleRanges,
    initialRange: 1,
    load: service.schedule,
    searchHint: 'Tìm theo tên PT hoặc hội viên...',
    text: (s) => '${s.trainerName} ${s.memberName ?? ''}',
    filters: const {
      'Tất cả': null,
      'Đã đặt': 'CONFIRMED',
      'Đã hoàn tất': 'COMPLETED',
      'Đã hủy': 'CANCELLED',
      'Còn trống': 'OPEN',
    },
    filterValue: (s) => s.status,
    empty: 'Không có buổi tập nào trong khoảng này.',
    columns: const ['Ngày', 'Giờ', 'Huấn luyện viên', 'Hội viên', 'Trạng thái'],
    cells: (s) {
      final start = vietnamClock(s.startAt), end = vietnamClock(s.endAt);
      return [
        shortDay(start),
        '${clockText(start)} – ${clockText(end)}',
        s.trainerName,
        s.memberName ?? '—',
        s.statusLabel,
      ];
    },
  );
}

class _ReportPage<T> extends StatefulWidget {
  final String title, searchHint, empty;
  final String? note;
  final ApiClient api;
  final List<DayRange> ranges;
  final int initialRange;
  final Future<List<T>> Function(DateTime from, DateTime to) load;
  final String Function(T row) text, filterValue;
  final Map<String, String?> filters;
  final List<String> columns;
  final List<String> Function(T row) cells;
  const _ReportPage({
    required this.title,
    required this.api,
    required this.ranges,
    required this.initialRange,
    required this.load,
    required this.searchHint,
    required this.text,
    required this.filters,
    required this.filterValue,
    required this.empty,
    required this.columns,
    required this.cells,
    this.note,
  });
  @override
  State<_ReportPage<T>> createState() => _ReportPageState<T>();
}

class _ReportPageState<T> extends State<_ReportPage<T>> {
  late int _range = widget.initialRange;
  String _query = '';
  String? _filter, _error;
  List<T>? _rows;
  int _read = 0;
  late final int _epoch = widget.api.sessionEpoch;
  bool get _current => mounted && widget.api.sessionEpoch == _epoch;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final read = ++_read;
    final range = widget.ranges[_range], today = vietnamToday();
    setState(() {
      _rows = null;
      _error = null;
    });
    try {
      final rows = await widget.load(
        today.add(Duration(days: range.fromOffset)),
        today.add(Duration(days: range.toOffset)),
      );
      // A slower answer for an earlier choice is dropped.
      if (_current && read == _read) setState(() => _rows = rows);
    } on ApiError catch (e) {
      if (_current && read == _read) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final rows = _rows
        ?.where(
          (r) =>
              widget.text(r).toLowerCase().contains(query) &&
              (_filter == null || widget.filterValue(r) == _filter),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (widget.note != null) ...[
            Text(widget.note!),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.ranges.length; i++)
                ChoiceChip(
                  label: Text(widget.ranges[i].label),
                  selected: i == _range,
                  onSelected: (_) {
                    _range = i;
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.searchHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in widget.filters.entries)
                FilterChip(
                  label: Text(entry.key),
                  selected: _filter == entry.value,
                  onSelected: (_) => setState(() => _filter = entry.value),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (rows == null)
            const LinearProgressIndicator()
          else if (rows.isEmpty)
            Text(widget.empty)
          else ...[
            Text('${rows.length} dòng'),
            const SizedBox(height: 8),
            ReportTable(
              columns: widget.columns,
              rows: [for (final r in rows) widget.cells(r)],
            ),
          ],
        ],
      ),
    );
  }
}

class ReportTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  const ReportTable({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: box.maxWidth),
          child: DataTable(
            border: tableGrid(context),
            headingRowColor: tableHeading(context),
            headingTextStyle: tableHeadingStyle,
            columnSpacing: 24,
            columns: [for (final c in columns) DataColumn(label: Text(c))],
            rows: [
              for (final row in rows)
                DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
            ],
          ),
        ),
      ),
    ),
  );
}
