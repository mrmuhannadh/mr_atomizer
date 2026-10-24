import 'package:flutter/material.dart';
import '../models/planner.dart';
import '../services/email_service.dart';
import '../services/notification_service.dart';
import '../services/planner_storage.dart';
import '../services/storage_service.dart';
import 'widgets.dart';

class PlannerSettingsScreen extends StatefulWidget {
  const PlannerSettingsScreen({super.key});
  @override
  State<PlannerSettingsScreen> createState() => _PlannerSettingsScreenState();
}

class _PlannerSettingsScreenState extends State<PlannerSettingsScreen> {
  final _to = TextEditingController();
  final _cc = TextEditingController();
  final _sig = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _from = TextEditingController();

  bool _loaded = false, _enabled = false, _planRem = true, _eodRem = true;
  bool _ssl = false, _hidePass = true, _testing = false, _simple = false;
  String _via = 'smtp';
  int _planH = 9, _planM = 30, _eodH = 17, _eodM = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await PlannerStorage.loadSettings();
    final pw = await PlannerStorage.loadPassword();
    if (!mounted) return;
    setState(() {
      _enabled = p.enabled;
      _to.text = p.to;
      _cc.text = p.cc;
      _sig.text = p.signature;
      _planRem = p.planReminder;
      _planH = p.planHour;
      _planM = p.planMinute;
      _eodRem = p.eodReminder;
      _eodH = p.eodHour;
      _eodM = p.eodMinute;
      _host.text = p.smtpHost;
      _port.text = '${p.smtpPort}';
      _ssl = p.smtpSsl;
      _user.text = p.smtpUser;
      _from.text = p.fromEmail;
      _pass.text = pw;
      _via = p.sendVia;
      _simple = p.outlookSimple;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_to, _cc, _sig, _host, _port, _user, _pass, _from]) {
      c.dispose();
    }
    super.dispose();
  }

  PlannerSettings _collect() => PlannerSettings(
        enabled: _enabled,
        to: _to.text.trim(),
        cc: _cc.text.trim(),
        signature: _sig.text.trim(),
        planReminder: _planRem,
        planHour: _planH,
        planMinute: _planM,
        eodReminder: _eodRem,
        eodHour: _eodH,
        eodMinute: _eodM,
        smtpHost: _host.text.trim(),
        smtpPort: int.tryParse(_port.text.trim()) ?? 587,
        smtpSsl: _ssl,
        smtpUser: _user.text.trim(),
        fromEmail: _from.text.trim().isEmpty ? _user.text.trim() : _from.text.trim(),
        sendVia: _via,
        outlookSimple: _simple,
      );

  void _preset(String host, int port, bool ssl) => setState(() {
        _host.text = host;
        _port.text = '$port';
        _ssl = ssl;
      });

  Future<void> _pickTime(bool plan) async {
    final t = await showTimePicker(
        context: context,
        initialTime: plan
            ? TimeOfDay(hour: _planH, minute: _planM)
            : TimeOfDay(hour: _eodH, minute: _eodM));
    if (t == null) return;
    setState(() {
      if (plan) {
        _planH = t.hour;
        _planM = t.minute;
      } else {
        _eodH = t.hour;
        _eodM = t.minute;
      }
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _test() async {
    final p = _collect();
    if (p.smtpHost.isEmpty || p.smtpUser.isEmpty || p.fromEmail.isEmpty) {
      _snack('Fill in the SMTP host, username and from email first.');
      return;
    }
    setState(() => _testing = true);
    try {
      await EmailService.sendTest(p, _pass.text);
      _snack('Test email sent to ${p.fromEmail} ✓');
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final p = _collect();
    if (p.enabled && parseRecipients(p.to).isEmpty) {
      _snack('Add at least one valid "To" email address.');
      return;
    }
    await PlannerStorage.saveSettings(p);
    await PlannerStorage.savePassword(_pass.text);
    await NotificationService.rescheduleIos(await StorageService.loadSettings());
    if (!mounted) return;
    _snack('Saved');
    Navigator.of(context).pop();
  }

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Daily plan & EoD emails')),
      body: centered(ListView(padding: const EdgeInsets.all(16), children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable daily plan & EoD emails'),
          subtitle: const Text('Shows the plan / EoD buttons on the dashboard'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),

        _h('Recipients'),
        TextField(
          controller: _to,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              labelText: 'To',
              helperText: 'Separate with commas. Names allowed: Priya Nair <priya@company.com>',
              helperMaxLines: 2,
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cc,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              labelText: 'CC', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sig,
          decoration: const InputDecoration(
              labelText: 'Your name (sign-off)', border: OutlineInputBorder()),
        ),

        _h('Reminders'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me to send the task plan'),
          value: _planRem,
          onChanged: (v) => setState(() => _planRem = v),
        ),
        if (_planRem)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.alarm),
            title: const Text('Plan reminder time'),
            subtitle: Text(TimeOfDay(hour: _planH, minute: _planM).format(context)),
            onTap: () => _pickTime(true),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me to send the EoD'),
          value: _eodRem,
          onChanged: (v) => setState(() => _eodRem = v),
        ),
        if (_eodRem)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.alarm),
            title: const Text('EoD reminder time'),
            subtitle: Text(TimeOfDay(hour: _eodH, minute: _eodM).format(context)),
            onTap: () => _pickTime(false),
          ),
        const Text('Reminders are sent Monday to Friday, and only if that email has not been sent yet.',
            style: TextStyle(fontSize: 12)),

        _h('Send emails with'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'smtp',
                label: Text('Email account'),
                icon: Icon(Icons.dns_outlined)),
            ButtonSegment(
                value: 'outlook',
                label: Text('Outlook app'),
                icon: Icon(Icons.open_in_new)),
          ],
          selected: {_via},
          onSelectionChanged: (v) => setState(() => _via = v.first),
        ),
        const SizedBox(height: 8),
        if (_via == 'outlook') ...[
          const Text(
              'The app prepares the email and opens it in Outlook. You review it and press Send yourself, '
              'then confirm in the app. No password is needed.',
              style: TextStyle(fontSize: 12)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Simple mode (plain text)'),
            subtitle: const Text(
                'Windows/Mac only. Off = formatted table draft. On = plain-text link, use this if the draft does not open in Outlook.'),
            value: _simple,
            onChanged: (v) => setState(() => _simple = v),
          ),
        ],
        if (_via == 'smtp') ...[
        _h('Email account (SMTP)'),
        const Text(
            'Emails are sent straight from this app through your mail server. '
            'Gmail and Outlook need an app password, not your normal password.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ActionChip(
              label: const Text('Gmail'),
              onPressed: () => _preset('smtp.gmail.com', 587, false)),
          ActionChip(
              label: const Text('Outlook / Office 365'),
              onPressed: () => _preset('smtp.office365.com', 587, false)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _host,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'SMTP host', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Port', border: OutlineInputBorder()),
            ),
          ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use SSL (port 465)'),
          subtitle: const Text('Off = STARTTLS (port 587)'),
          value: _ssl,
          onChanged: (v) => setState(() => _ssl = v),
        ),
        TextField(
          controller: _user,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              labelText: 'Username (usually your email)',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          obscureText: _hidePass,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Password / app password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
                icon: Icon(_hidePass ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hidePass = !_hidePass)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _from,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              labelText: 'From email',
              helperText: 'Leave empty to use the username',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _testing ? null : _test,
          icon: _testing
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.mark_email_read_outlined),
          label: const Text('Send test email to myself'),
        ),

        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Save'),
        ),
      ])),
    );
  }
}
