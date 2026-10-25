import 'package:flutter/material.dart';
import '../models/planner.dart';
import '../models/settings.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import '../services/planner_storage.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';
import 'eod_screen.dart';
import 'history_screen.dart';
import 'plan_screen.dart';
import 'planner_settings_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  double? _hours;
  double _goal = 8;
  bool _loading = false, _failed = false;
  PlannerSettings _planner = PlannerSettings();
  DayPlan? _day;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final s = await StorageService.loadSettings();
    final pl = await PlannerStorage.loadSettings();
    final day = await PlannerStorage.loadDay();
    final h = await fetchTodayHours();
    if (!mounted) return;
    setState(() {
      _goal = s.minHours;
      _planner = pl;
      _day = day;
      _hours = h;
      _failed = h == null;
      _loading = false;
    });
    // iOS: skip today's worklog reminder if the goal is already met
    await NotificationService.rescheduleIos(s,
        skipToday: h != null && h >= s.minHours);
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _refresh();
  }

  Widget _hoursSection() {
    final h = _hours ?? 0;
    final ok = h >= _goal;
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()));
    }
    if (_failed) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('Could not load worklogs. Tap refresh to retry.')));
    }
    return Column(children: [
      const SizedBox(height: 16),
      Icon(ok ? Icons.check_circle : Icons.schedule,
          size: 64, color: ok ? Colors.green : Colors.orange),
      const SizedBox(height: 12),
      Text('Today: ${h.toStringAsFixed(1)}h / ${_goal.toStringAsFixed(0)}h',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(ok ? 'All good, nothing to log.' : 'Remember to log your time.'),
      const SizedBox(height: 16),
    ]);
  }

  Widget _statusRow(IconData icon, String label, String value, bool done) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18, color: done ? Colors.green : Colors.grey),
        ]),
      );

  Widget _plannerCard() {
    if (!_planner.enabled) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.mark_email_read_outlined),
          title: const Text('Automate your daily emails'),
          subtitle: const Text('Send a task plan and EoD, and log time in Jira.'),
          trailing: FilledButton.tonal(
              onPressed: () => _open(const PlannerSettingsScreen()),
              child: const Text('Set up')),
        ),
      );
    }
    final d = _day ?? DayPlan(date: dateKey(DateTime.now()));
    final planned = d.tasks.where((t) => t.inPlan).toList();
    final plannedH = planned.fold<double>(0, (a, t) => a + t.estimate);
    final worked = d.tasks.where((t) => t.worked > 0 && t.logged).fold<double>(0, (a, t) => a + t.worked);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event_note),
            const SizedBox(width: 8),
            Text("Today's plan", style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 8),
          _statusRow(
              Icons.assignment_outlined,
              'Task plan',
              d.planSent
                  ? 'Sent · ${planned.length} task${planned.length == 1 ? '' : 's'} · ${hoursLabel(plannedH)}'
                  : 'Not sent yet',
              d.planSent),
          _statusRow(
              Icons.nightlight_outlined,
              'EoD',
              d.eodSent ? 'Sent · ${hoursLabel(worked)} logged' : 'Not sent yet',
              d.eodSent),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.tonal(
                  onPressed: () => _open(const PlanScreen()),
                  child: Text(d.planSent ? 'Edit plan' : 'Send plan')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                  onPressed: () => _open(const EodScreen()),
                  child: Text(d.eodSent ? 'Update EoD' : 'Send EoD')),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jira Mate'), actions: [
        IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Log history',
            onPressed: () => _open(const HistoryScreen())),
        IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh),
        IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _open(const SettingsScreen())),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
              padding: const EdgeInsets.all(16),
              children: [_hoursSection(), _plannerCard()]),
        ),
      ),
    );
  }
}
