import 'dart:convert';
import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/planner.dart';
import '../utils/format.dart';
import 'planner_storage.dart';
import 'storage_service.dart';

/// Everything needed to send an email by any method.
class EmailDraft {
  final String subject, html, plain;
  final List<String> to, cc;
  final String? messageId, inReplyTo;
  EmailDraft({
    required this.subject,
    required this.html,
    required this.plain,
    required this.to,
    required this.cc,
    this.messageId,
    this.inReplyTo,
  });
}

class EmailService {
  // ======================= building the content =======================

  static String _newId(String fromEmail) {
    final domain = fromEmail.contains('@') ? fromEmail.split('@').last : 'localhost';
    return '<${DateTime.now().microsecondsSinceEpoch}.jira-notifier@$domain>';
  }

  static String _link(String base, String key) => base.isEmpty
      ? esc(key)
      : '<a href="${esc(base)}/browse/${esc(key)}">${esc(key)}</a>';

  /// [rows] cells are already-escaped HTML.
  static String _table(List<String> head, List<List<String>> rows) {
    const cell =
        'border:1px solid #d0d5dd;padding:6px 10px;text-align:left;vertical-align:top;';
    final b = StringBuffer(
        '<table style="border-collapse:collapse;font-family:Arial,sans-serif;font-size:14px;">');
    b.write('<tr>${head.map((h) => '<th style="$cell background:#f2f4f7;">${esc(h)}</th>').join()}</tr>');
    for (final r in rows) {
      b.write('<tr>${r.map((c) => '<td style="$cell">$c</td>').join()}</tr>');
    }
    b.write('</table>');
    return b.toString();
  }

  static String _page(String inner) =>
      '<div style="font-family:Arial,sans-serif;font-size:14px;color:#1d2939;">$inner</div>';

  static String _sign(PlannerSettings p) => p.signature.trim().isEmpty
      ? '<p>Regards</p>'
      : '<p>Regards,<br>${esc(p.signature.trim())}</p>';

  static List<String> _emails(String raw) =>
      parseRecipients(raw).map((r) => r.email).toList();

  static Future<EmailDraft> _planDraft(PlannerSettings p, DayPlan day) async {
    final creds = await StorageService.credentials();
    final base = creds?.url ?? '';
    final now = DateTime.now();
    final tasks = day.tasks.where((t) => t.inPlan).toList();
    final g = greetingFor(p.to);
    final total = tasks.fold<double>(0, (a, t) => a + t.estimate);

    final rows = <List<String>>[
      for (final t in tasks)
        [
          _link(base, t.key),
          esc(t.summary),
          esc(hoursLabel(t.estimate)),
          esc(t.status.isEmpty ? '-' : t.status),
        ],
    ];
    rows.add(['', '<b>Total</b>', '<b>${esc(hoursLabel(total))}</b>', '']);

    final html = _page('<p>Dear ${esc(g)},</p>'
        '<p>This is the task plan for ${esc(prettyDate(now))},</p>'
        '${_table(['Jira ID', 'Summary', 'Estimate', 'Status'], rows)}'
        '${_sign(p)}');

    final plain = StringBuffer(
        'Dear $g,\n\nThis is the task plan for ${prettyDate(now)},\n\n');
    plain.writeln('| Jira ID | Summary | Estimate | Status |');
    plain.writeln('|---|---|---|---|');
    for (final t in tasks) {
      plain.writeln(
          '| ${t.key} | ${t.summary} | ${hoursLabel(t.estimate)} | ${t.status.isEmpty ? '-' : t.status} |');
    }
    plain.writeln('\nTotal estimate: ${hoursLabel(total)}\n\nRegards,\n${p.signature}');

    return EmailDraft(
      subject: 'Task plan for ${prettyDate(now)}',
      html: html,
      plain: plain.toString(),
      to: _emails(p.to),
      cc: _emails(p.cc),
      messageId: _newId(p.fromEmail),
    );
  }

  static Future<EmailDraft> _eodDraft(PlannerSettings p, DayPlan day) async {
    final creds = await StorageService.credentials();
    final base = creds?.url ?? '';
    final now = DateTime.now();
    final tasks = day.tasks.where((t) => t.worked > 0).toList();
    final g = greetingFor(p.to);
    final total = tasks.fold<double>(0, (a, t) => a + t.worked);
    final replying = day.planSubject != null;

    final rows = <List<String>>[
      for (final t in tasks)
        [
          _link(base, t.key),
          esc(t.summary),
          esc(t.inPlan ? hoursLabel(t.estimate) : '-'),
          esc(hoursLabel(t.worked)),
          esc(t.note.trim()),
        ],
    ];
    rows.add(['', '<b>Total</b>', '', '<b>${esc(hoursLabel(total))}</b>', '']);

    final html = _page('<p>Dear ${esc(g)},</p>'
        '<p>This is the EoD for ${esc(prettyDate(now))},</p>'
        '${_table(['Jira ID', 'Summary', 'Estimation', 'Time spent', 'Notes'], rows)}'
        '${_sign(p)}');

    final plain = StringBuffer(
        'Dear $g,\n\nThis is the EoD for ${prettyDate(now)},\n\n');
    for (final t in tasks) {
      plain.writeln(
          '${t.key}  |  ${t.summary}  |  planned ${t.inPlan ? hoursLabel(t.estimate) : '-'}  |  spent ${hoursLabel(t.worked)}'
          '${t.note.trim().isEmpty ? '' : '  |  ${t.note.trim()}'}');
    }
    plain.writeln('\nTotal: ${hoursLabel(total)}\n\nRegards,\n${p.signature}');

    return EmailDraft(
      subject: replying ? 'Re: ${day.planSubject}' : 'EoD - ${prettyDate(now)}',
      html: html,
      plain: plain.toString(),
      to: _emails(p.to),
      cc: _emails(p.cc),
      inReplyTo: day.planMessageId, // only known when the plan went out via SMTP
    );
  }

  // ======================= method 1: SMTP =======================

  static SmtpServer _server(PlannerSettings p, String pw) => SmtpServer(
        p.smtpHost.trim(),
        port: p.smtpPort,
        ssl: p.smtpSsl, // false = STARTTLS (587), true = SSL (465)
        username: p.smtpUser.trim(),
        password: pw,
      );

  static Future<void> _smtp(PlannerSettings p, EmailDraft d) async {
    final pw = await PlannerStorage.loadPassword();
    final m = Message()
      ..from = Address(p.fromEmail.trim(), p.signature.trim())
      ..subject = d.subject
      ..html = d.html
      ..text = d.plain;
    m.recipients.addAll(d.to.map((e) => Address(e)));
    m.ccRecipients.addAll(d.cc.map((e) => Address(e)));
    if (d.messageId != null) m.headers['Message-ID'] = d.messageId!;
    if (d.inReplyTo != null) {
      m.headers['In-Reply-To'] = d.inReplyTo!;
      m.headers['References'] = d.inReplyTo!;
    }
    await _sendMail(m, _server(p, pw));
  }

  static Future<void> _sendMail(Message m, SmtpServer s) async {
    try {
      await send(m, s, timeout: const Duration(seconds: 30));
    } on MailerException catch (e) {
      final problems = e.problems.map((x) => x.msg).join('; ');
      throw Exception('Email failed: ${problems.isEmpty ? e.message : problems}');
    }
  }

  static Future<void> sendPlan(PlannerSettings p, DayPlan day) async {
    final d = await _planDraft(p, day);
    await _smtp(p, d);
    day.planSent = true;
    day.planMessageId = d.messageId;
    day.planSubject = d.subject;
  }

  static Future<void> sendEod(PlannerSettings p, DayPlan day) async {
    final d = await _eodDraft(p, day);
    await _smtp(p, d);
    day.eodSent = true;
  }

  static Future<void> sendTest(PlannerSettings p, String password) async {
    final m = Message()
      ..from = Address(p.fromEmail.trim(), p.signature.trim())
      ..recipients.add(Address(p.fromEmail.trim()))
      ..subject = 'Jira Mate test email'
      ..text = 'Your email settings work. You can now send task plans and EoD emails.';
    await _sendMail(m, _server(p, password));
  }

  // ======================= method 2: Outlook app =======================
  // The app opens a filled-in email; the user reviews it and presses Send.

  static Future<EmailDraft> openPlanInOutlook(
      PlannerSettings p, DayPlan day) async {
    final d = await _planDraft(p, day);
    await _openCompose(p, d);
    day.planSubject = d.subject; // lets the EoD use the same subject with "Re:"
    day.planMessageId = null; // Outlook assigns its own id, we can't know it
    return d;
  }

  static Future<EmailDraft> openEodInOutlook(
      PlannerSettings p, DayPlan day) async {
    final d = await _eodDraft(p, day);
    await _openCompose(p, d);
    return d;
  }

  static Future<void> _openCompose(PlannerSettings p, EmailDraft d) async {
    final desktop = Platform.isWindows || Platform.isMacOS;

    // Desktop: an unsent .eml draft keeps the formatted table.
    if (desktop && !p.outlookSimple) {
      try {
        final f = await _writeEml(d);
        if (await launchUrl(Uri.file(f.path))) return;
      } catch (_) {/* fall back to the simple link below */}
    }

    final to = d.to.join(',');
    final cc = d.cc.join(',');
    final subject = Uri.encodeComponent(d.subject);
    final body = Uri.encodeComponent(d.plain.replaceAll('\n', '\r\n'));

    // iPhone / iPad: open the Outlook app directly if installed.
    if (Platform.isIOS) {
      try {
        final u = Uri.parse(
            'ms-outlook://compose?to=$to&cc=$cc&subject=$subject&body=$body');
        if (await launchUrl(u, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }

    final mailto = Uri.parse(
        'mailto:$to?${cc.isEmpty ? '' : 'cc=$cc&'}subject=$subject&body=$body');
    final ok = await launchUrl(mailto, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception(
          'Could not open an email app. Install Outlook or set it as your default mail app.');
    }
  }

  static Future<File> _writeEml(EmailDraft d) async {
    String b64(String s) {
      final enc = base64.encode(utf8.encode(s));
      return RegExp('.{1,76}').allMatches(enc).map((m) => m.group(0)).join('\r\n');
    }

    String hdr(String s) => s.runes.every((r) => r < 128)
        ? s
        : '=?UTF-8?B?${base64.encode(utf8.encode(s))}?=';

    final html = d.html.trimLeft().startsWith('<html')
        ? d.html
        : '<html><body>${d.html}</body></html>';

    final headers = <String>[
      'X-Unsent: 1', // makes Outlook open it as an editable draft
      'To: ${d.to.join(', ')}',
      if (d.cc.isNotEmpty) 'Cc: ${d.cc.join(', ')}',
      'Subject: ${hdr(d.subject)}',
      'MIME-Version: 1.0',
      'Content-Type: text/html; charset=utf-8',
      'Content-Transfer-Encoding: base64',
    ];
    final eml = '${headers.join('\r\n')}\r\n\r\n${b64(html)}\r\n';

    final dir = await getTemporaryDirectory();
    final f = File(
        '${dir.path}${Platform.pathSeparator}jira_notifier_${DateTime.now().millisecondsSinceEpoch}.eml');
    return f.writeAsString(eml);
  }
}
