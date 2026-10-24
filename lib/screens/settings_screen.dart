import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'connect_screen.dart';
import 'planner_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ReminderSettings? _s;
  static const _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    StorageService.loadSettings().then((s) => setState(() => _s = s));
  }

  Future<void> _save() async {
    await StorageService.saveSettings(_s!);
    await NotificationService.rescheduleIos(_s!);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: _s!.hour, minute: _s!.minute));
    if (t == null) return;
    setState(() {
      _s!.hour = t.hour;
      _s!.minute = t.minute;
    });
    await _save();
  }

  Future<void> _disconnect() async {
    await StorageService.disconnect();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ConnectScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Reminder settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(
          leading: const Icon(Icons.alarm),
          title: const Text('Time-log reminder time'),
          subtitle:
              Text(TimeOfDay(hour: s.hour, minute: s.minute).format(context)),
          onTap: _pickTime,
        ),
        const SizedBox(height: 8),
        const Text('Remind me on'),
        Wrap(spacing: 8, children: [
          for (var i = 1; i <= 7; i++)
            FilterChip(
              label: Text(_names[i - 1]),
              selected: s.weekdays.contains(i),
              onSelected: (v) async {
                setState(() {
                  final list = List<int>.from(s.weekdays);
                  v ? list.add(i) : list.remove(i);
                  s.weekdays = list..sort();
                });
                await _save();
              },
            ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: Text('Minimum hours per day')),
          IconButton(
              icon: const Icon(Icons.remove),
              onPressed: s.minHours > 1
                  ? () async {
                      setState(() => s.minHours -= 0.5);
                      await _save();
                    }
                  : null),
          Text(s.minHours.toStringAsFixed(1)),
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: s.minHours < 24
                  ? () async {
                      setState(() => s.minHours += 0.5);
                      await _save();
                    }
                  : null),
        ]),
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mark_email_read_outlined),
          title: const Text('Daily plan & EoD emails'),
          subtitle: const Text('Recipients, reminders, email account'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PlannerSettingsScreen())),
        ),
        const Divider(height: 32),
        OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.logout),
            label: const Text('Disconnect Jira')),
      ]),
    );
  }
}
