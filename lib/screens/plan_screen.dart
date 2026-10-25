import 'package:flutter/material.dart';
import '../models/planner.dart';
import '../services/email_service.dart';
import '../services/notification_service.dart';
import '../services/planner_storage.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';
import 'planner_settings_screen.dart';
import 'widgets.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  DayPlan? _day;
  PlannerSettings? _p;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await PlannerStorage.loadDay();
    final p = await PlannerStorage.loadSettings();
    if (!mounted) return;
    setState(() {
      _day = d;
      _p = p;
    });
  }

  Future<void> _add() async {
    final d = _day!;
    final picked =
        await showIssuePicker(context, exclude: d.tasks.where((t) => t.inPlan).map((t) => t.key).toSet());
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final i in picked) {
        final existing = d.tasks.where((t) => t.key == i.key);
        if (existing.isNotEmpty) {
          existing.first.inPlan = true; // was an EoD-only task
        } else {
          d.tasks.add(PlanTask(
              key: i.key, summary: i.summary, status: i.status, estimate: 1));
        }
      }
    });
    await PlannerStorage.saveDay(d);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PlannerSettingsScreen()));
    _load();
  }

  Future<void> _send() async {
    final d = _day!, p = _p!;
    final tasks = d.tasks.where((t) => t.inPlan).toList();
    if (tasks.isEmpty) {
      setState(() => _error = 'Add at least one task.');
      return;
    }
    if (tasks.any((t) => t.estimate <= 0)) {
      setState(() => _error = 'Every task needs an estimate above 0.');
      return;
    }
    if (!p.emailReady) {
      setState(() => _error = 'Set the recipients and email account first.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (p.sendVia == 'outlook') {
        final draft = await EmailService.openPlanInOutlook(p, d);
        if (!mounted) return;
        final sent = await confirmSentDialog(context, draft.plain);
        if (!sent) {
          await PlannerStorage.saveDay(d);
          if (mounted) {
            setState(() => _error =
                'Not marked as sent yet. Tap "Send task plan" again once you have sent it.');
          }
          return;
        }
        d.planSent = true;
      } else {
        await EmailService.sendPlan(p, d);
      }
      await PlannerStorage.saveDay(d);
      await NotificationService.rescheduleIos(await StorageService.loadSettings());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Task plan sent ✓')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _day, p = _p;
    if (d == null || p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final cs = Theme.of(context).colorScheme;
    final tasks = d.tasks.where((t) => t.inPlan).toList();
    final total = tasks.fold<double>(0, (a, t) => a + t.estimate);

    return Scaffold(
      appBar: AppBar(title: const Text('Task plan')),
      body: centered(ListView(padding: const EdgeInsets.all(16), children: [
        Text(prettyDate(DateTime.now()),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(p.to.trim().isEmpty ? 'To: not set' : 'To: ${p.to}'),
            subtitle: Text(p.cc.trim().isEmpty ? 'No CC' : 'CC: ${p.cc}'),
            trailing: TextButton(onPressed: _openSettings, child: const Text('Edit')),
          ),
        ),
        if (d.planSent)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.check_circle, color: cs.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Today\'s plan was already sent. You can update it and send again.',
                      style: TextStyle(color: cs.onSecondaryContainer))),
            ]),
          ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No tasks yet. Add the tasks you plan to work on.'))),
        for (final t in tasks)
          Card(
            key: ValueKey(t.key),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(t.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 8),
                HoursField(
                  key: ValueKey('est-${t.key}'),
                  label: 'Estimate',
                  value: t.estimate,
                  onChanged: (v) {
                    setState(() => t.estimate = v);
                    PlannerStorage.saveDay(d);
                  },
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      if (t.logged || t.worked > 0) {
                        t.inPlan = false;
                      } else {
                        d.tasks.remove(t);
                      }
                    });
                    PlannerStorage.saveDay(d);
                  },
                ),
              ]),
            ),
          ),
        OutlinedButton.icon(
            onPressed: _sending ? null : _add,
            icon: const Icon(Icons.add),
            label: const Text('Add tasks from Jira')),
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerRight,
            child: Text('Total estimate: ${hoursLabel(total)}',
                style: Theme.of(context).textTheme.titleMedium)),
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: cs.errorContainer, borderRadius: BorderRadius.circular(8)),
            child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: _sending
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          label: Text(d.planSent ? 'Send updated plan' : 'Send task plan'),
        ),
      ])),
    );
  }
}
