import 'package:flutter/material.dart';
import 'package:jira_manager/theme/glass_theme.dart';
import '../models/worklog_entry.dart';
import '../services/jira_service.dart';
import '../services/storage_service.dart';

enum RangeMode { thisWeek, thisMonth, custom }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  RangeMode _mode = RangeMode.thisWeek;
  late DateTimeRange _range = _presetRange(RangeMode.thisWeek);
  double _goal = 8;
  bool _loading = false;
  String? _error;
  List<WorklogEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTimeRange _presetRange(RangeMode m) {
    final t = _today;
    if (m == RangeMode.thisMonth) {
      return DateTimeRange(start: DateTime(t.year, t.month, 1), end: t);
    }
    return DateTimeRange(
        start: t.subtract(Duration(days: t.weekday - 1)), end: t);
  }

  Future<void> _onModeChanged(RangeMode? m) async {
    if (m == null) return;
    if (m == RangeMode.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2015),
        lastDate: _today,
        initialDateRange: _range,
      );
      if (picked == null) return; // cancelled: keep previous selection
      setState(() {
        _mode = m;
        _range = DateTimeRange(start: picked.start, end: picked.end);
      });
    } else {
      setState(() {
        _mode = m;
        _range = _presetRange(m);
      });
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await StorageService.credentials();
      if (c == null) throw Exception('Not connected to Jira');
      final s = await StorageService.loadSettings();
      final data = await JiraService(c.url, c.email, c.token)
          .worklogsBetween(_range.start, _range.end, c.accountId);
      if (!mounted) return;
      setState(() {
        _goal = s.minHours;
        _entries = data;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load history: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- helpers ----------
  String _fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _dayLabel(DateTime d) =>
      '${_dayNames[d.weekday - 1]}, ${d.day} ${_monthNames[d.month - 1]}';

  String _rangeLabel() =>
      '${_dayLabel(_range.start)}  →  ${_dayLabel(_range.end)}';

  /// Days from newest to oldest. Weekdays always shown (even with 0h);
  /// weekends only if something was logged.
  List<DateTime> _days(Map<DateTime, List<WorklogEntry>> byDay) {
    final days = <DateTime>[];
    for (var d = _range.end;
    !d.isBefore(_range.start);
    d = DateTime(d.year, d.month, d.day - 1)) {
      if (d.weekday <= 5 || byDay.containsKey(d)) days.add(d);
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, List<WorklogEntry>>{};
    for (final e in _entries) {
      byDay.putIfAbsent(e.date, () => []).add(e);
    }
    final totalSeconds = _entries.fold<int>(0, (a, e) => a + e.seconds);

    return Scaffold(
      appBar: AppBar(title: const Text('Log History'), actions: [
        IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load),
      ]),
      body: Column(children: [
        // ----- Range selector -----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<RangeMode>(
                initialValue: _mode,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: const [
                  DropdownMenuItem(
                      value: RangeMode.thisWeek, child: Text('This week')),
                  DropdownMenuItem(
                      value: RangeMode.thisMonth, child: Text('This month')),
                  DropdownMenuItem(
                      value: RangeMode.custom, child: Text('Pick date range…')),
                ],
                onChanged: _loading ? null : _onModeChanged,
              ),
            ),
            if (_mode == RangeMode.custom)
              IconButton(
                  tooltip: 'Change dates',
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: _loading ? null : () => _onModeChanged(RangeMode.custom)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_rangeLabel(),
                  style: Theme.of(context).textTheme.bodySmall)),
        ),
        // ----- Total -----
        if (!_loading && _error == null)
          GlassCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Total logged'),
              trailing: Text(_fmt(totalSeconds),
                  style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
        // ----- Body -----
        Expanded(child: _body(byDay)),
      ]),
    );
  }

  Widget _body(Map<DateTime, List<WorklogEntry>> byDay) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center)));
    }
    final days = _days(byDay);
    if (days.isEmpty) return const Center(child: Text('No days in this range.'));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final items = byDay[day] ?? [];
        final secs = items.fold<int>(0, (a, e) => a + e.seconds);
        final isWeekday = day.weekday <= 5;
        final short = isWeekday && secs < _goal * 3600;
        final color = short ? Colors.orange.shade800 : Colors.green.shade700;

        return GlassCard(
          child: ExpansionTile(
            leading: Icon(short ? Icons.warning_amber_rounded : Icons.check_circle,
                color: color),
            title: Text(_dayLabel(day)),
            subtitle: items.isEmpty
                ? const Text('Nothing logged')
                : Text('${items.length} entr${items.length == 1 ? 'y' : 'ies'}'),
            trailing: Text(_fmt(secs),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            children: [
              for (final e in items)
                ListTile(
                  dense: true,
                  title: Text('${e.issueKey}  ${e.summary}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: e.comment.isEmpty ? null : Text(e.comment),
                  trailing: Text(_fmt(e.seconds)),
                ),
            ],
          ),
        );
      },
    );
  }
}