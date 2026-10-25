import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jira_manager/theme/glass_theme.dart';
import '../models/planner.dart';
import '../services/email_service.dart';
import '../services/jira_service.dart';
import '../services/notification_service.dart';
import '../services/planner_storage.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';
import 'planner_settings_screen.dart';
import 'widgets.dart';

class EodScreen extends StatefulWidget {
  const EodScreen({super.key});
  @override
  State<EodScreen> createState() => _EodScreenState();
}

class _EodScreenState extends State<EodScreen> {
  DayPlan? _day;
  PlannerSettings? _p;
  bool _sending = false;
  String _status = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await PlannerStorage.loadDay();
    final p = await PlannerStorage.loadSettings();
    for (final t in d.tasks) {
      // default: worked = planned
      if (!t.logged && t.worked == 0 && t.inPlan) t.worked = t.estimate;
    }
    if (!mounted) return;
    setState(() {
      _day = d;
      _p = p;
    });
  }

  Future<void> _add() async {
    final d = _day!;
    final picked =
        await showIssuePicker(context, exclude: d.tasks.map((t) => t.key).toSet());
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final i in picked) {
        d.tasks.add(PlanTask(
            key: i.key, summary: i.summary, estimate: 0, worked: 1, inPlan: false));
      }
    });
    await PlannerStorage.saveDay(d);
  }

  String _dioMsg(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final em = data['errorMessages'];
      if (em is List && em.isNotEmpty) return em.join(', ');
      final er = data['errors'];
      if (er is Map && er.isNotEmpty) return er.values.join(', ');
    }
    return e.response?.statusCode != null
        ? 'HTTP ${e.response!.statusCode}'
        : 'network error';
  }

  Future<void> _submit() async {
    final d = _day!, p = _p!;
    final active = d.tasks.where((t) => t.worked > 0).toList();
    if (active.isEmpty) {
      setState(() => _error = 'Enter the time worked for at least one task.');
      return;
    }
    if (!p.emailReady) {
      setState(() => _error = 'Set the recipients and email account first.');
      return;
    }
    final c = await StorageService.credentials();
    if (c == null) {
      setState(() => _error = 'Not connected to Jira.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    final jira = JiraService(c.url, c.email, c.token);
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day, 9);
    var offset = d.tasks
        .where((t) => t.logged)
        .fold<int>(0, (a, t) => a + (t.worked * 3600).round());
    final failures = <String>[];
    final todo = active.where((t) => !t.logged).toList();

    for (var i = 0; i < todo.length; i++) {
      final t = todo[i];
      setState(() => _status = 'Logging time ${i + 1}/${todo.length} (${t.key})…');
      final secs = (t.worked * 3600).round();
      var start = dayStart.add(Duration(seconds: offset));
      if (start.day != now.day) start = dayStart;
      try {
        await jira.addWorklog(t.key, secs, start, t.note);
        t.logged = true;
        offset += secs;
        await PlannerStorage.saveDay(d);
      } on DioException catch (e) {
        failures.add('${t.key}: ${_dioMsg(e)}');
      } catch (e) {
        failures.add('${t.key}: $e');
      }
    }

    if (failures.isNotEmpty && mounted) {
      final sendAnyway = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Some time logs failed'),
          content: Text('${failures.join('\n')}\n\n'
              'Tasks that were logged are saved, so retrying will not duplicate them.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Close')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send email anyway')),
          ],
        ),
      );
      if (sendAnyway != true) {
        if (mounted) setState(() => _sending = false);
        return;
      }
    }

    try {
      setState(() => _status = 'Sending EoD email…');
      if (p.sendVia == 'outlook') {
        final draft = await EmailService.openEodInOutlook(p, d);
        if (!mounted) return;
        final sent = await confirmSentDialog(context, draft.plain);
        if (!sent) {
          await PlannerStorage.saveDay(d);
          if (mounted) {
            setState(() => _error =
                'Time is logged. Tap the button again to reopen the EoD email once you are ready to send it.');
          }
          return;
        }
        d.eodSent = true;
      } else {
        await EmailService.sendEod(p, d);
      }
      await PlannerStorage.saveDay(d);
      await NotificationService.rescheduleIos(await StorageService.loadSettings());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(failures.isEmpty
              ? 'EoD sent and time logged ✓'
              : 'EoD sent (some logs failed)')));
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
    final total =
        d.tasks.where((t) => t.worked > 0).fold<double>(0, (a, t) => a + t.worked);

    return Scaffold(
      appBar: AppBar(title: const Text('End of day')),
      body: centered(ListView(padding: const EdgeInsets.all(16), children: [
        Text(prettyDate(DateTime.now()),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
            d.planSent
                ? 'The EoD will be sent as a reply to today\'s task plan.'
                : 'No plan was sent today, so this will be a new email.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text('To: ${p.to.trim().isEmpty ? 'not set' : p.to}',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (d.tasks.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No tasks yet. Add what you worked on.'))),
        for (final t in d.tasks)
          GlassCard(
            key: ValueKey('eod-${t.key}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: Text('${t.key}  ${t.summary}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (t.logged)
                    const Icon(Icons.check_circle, color: Colors.green)
                  else
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() => d.tasks.remove(t));
                        PlannerStorage.saveDay(d);
                      },
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: Text(t.inPlan
                          ? 'Planned: ${hoursLabel(t.estimate)}'
                          : 'Not in today\'s plan')),
                  HoursField(
                    key: ValueKey('worked-${t.key}'),
                    label: 'Worked',
                    value: t.worked,
                    enabled: !t.logged,
                    onChanged: (v) {
                      setState(() => t.worked = v);
                      PlannerStorage.saveDay(d);
                    },
                  ),
                ]),
                const SizedBox(height: 10),
                TextFormField(
                  key: ValueKey('note-${t.key}'),
                  initialValue: t.note,
                  enabled: !t.logged,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: t.logged
                        ? 'Logged in Jira'
                        : 'Time log description (optional)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    t.note = v;
                    PlannerStorage.saveDay(d);
                  },
                ),
              ]),
            ),
          ),
        OutlinedButton.icon(
            onPressed: _sending ? null : _add,
            icon: const Icon(Icons.add),
            label: const Text('Add another task')),
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerRight,
            child: Text('Total worked: ${hoursLabel(total)}',
                style: Theme.of(context).textTheme.titleMedium)),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Tasks with 0h are left out of the email and not logged.',
              textAlign: TextAlign.right),
        ),
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
          onPressed: _sending ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: _sending
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          label: Text(_sending
              ? _status
              : (d.eodSent ? 'Send updated EoD & log new time' : 'Send EoD & log time in Jira')),
        ),
      ])),
    );
  }
}
