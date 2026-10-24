import '../models/settings.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String prettyDate(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

String hoursLabel(double h) {
  var s = h.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '${s}h';
}

String _p2(int n) => n.toString().padLeft(2, '0');

/// Jira worklog "started" format: 2026-10-25T09:00:00.000+0530
String jiraStarted(DateTime d) {
  final off = d.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final h = _p2(off.inHours.abs());
  final m = _p2(off.inMinutes.abs() % 60);
  return '${dateKey(d)}T${_p2(d.hour)}:${_p2(d.minute)}:${_p2(d.second)}.000$sign$h$m';
}

String esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
