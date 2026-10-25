class JiraIssue {
  final String key, summary, status, priority;
  JiraIssue(this.key, this.summary, this.status, this.priority);
}

class PlanTask {
  final String key;
  String summary;
  String status; // Jira status when the task was added
  double estimate; // planned hours
  double worked; // hours worked (EoD)
  String note; // worklog description
  bool logged; // already logged in Jira
  bool inPlan; // false = added only at EoD

  PlanTask({
    required this.key,
    required this.summary,
    this.status = '',
    this.estimate = 1,
    this.worked = 0,
    this.note = '',
    this.logged = false,
    this.inPlan = true,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'summary': summary,
    'status': status,
    'estimate': estimate,
    'worked': worked,
    'note': note,
    'logged': logged,
    'inPlan': inPlan,
  };

  factory PlanTask.fromJson(Map<String, dynamic> j) => PlanTask(
    key: j['key'] as String,
    summary: (j['summary'] ?? '') as String,
    status: (j['status'] ?? '') as String,
    estimate: (j['estimate'] as num?)?.toDouble() ?? 1,
    worked: (j['worked'] as num?)?.toDouble() ?? 0,
    note: (j['note'] ?? '') as String,
    logged: j['logged'] == true,
    inPlan: j['inPlan'] != false,
  );
}

class DayPlan {
  String date;
  List<PlanTask> tasks;
  bool planSent;
  bool eodSent;
  String? planMessageId;
  String? planSubject;

  DayPlan({
    required this.date,
    List<PlanTask>? tasks,
    this.planSent = false,
    this.eodSent = false,
    this.planMessageId,
    this.planSubject,
  }) : tasks = tasks ?? [];

  Map<String, dynamic> toJson() => {
    'date': date,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'planSent': planSent,
    'eodSent': eodSent,
    'planMessageId': planMessageId,
    'planSubject': planSubject,
  };

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
    date: j['date'] as String,
    tasks: (j['tasks'] as List? ?? [])
        .map((e) => PlanTask.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    planSent: j['planSent'] == true,
    eodSent: j['eodSent'] == true,
    planMessageId: j['planMessageId'] as String?,
    planSubject: j['planSubject'] as String?,
  );
}

class PlannerSettings {
  bool enabled;
  String to, cc, signature;
  bool planReminder;
  int planHour, planMinute;
  bool eodReminder;
  int eodHour, eodMinute;
  String smtpHost;
  int smtpPort;
  bool smtpSsl;
  String smtpUser, fromEmail;
  String sendVia; // 'smtp' or 'outlook'
  bool outlookSimple; // true = plain-text link instead of formatted draft file

  PlannerSettings({
    this.enabled = false,
    this.to = '',
    this.cc = '',
    this.signature = '',
    this.planReminder = true,
    this.planHour = 9,
    this.planMinute = 30,
    this.eodReminder = true,
    this.eodHour = 17,
    this.eodMinute = 30,
    this.smtpHost = '',
    this.smtpPort = 587,
    this.smtpSsl = false,
    this.smtpUser = '',
    this.fromEmail = '',
    this.sendVia = 'smtp',
    this.outlookSimple = false,
  });

  bool get emailReady =>
      parseRecipients(to).isNotEmpty &&
          (sendVia == 'outlook' ||
              (smtpHost.trim().isNotEmpty &&
                  smtpUser.trim().isNotEmpty &&
                  fromEmail.trim().isNotEmpty));

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'to': to,
    'cc': cc,
    'signature': signature,
    'planReminder': planReminder,
    'planHour': planHour,
    'planMinute': planMinute,
    'eodReminder': eodReminder,
    'eodHour': eodHour,
    'eodMinute': eodMinute,
    'smtpHost': smtpHost,
    'smtpPort': smtpPort,
    'smtpSsl': smtpSsl,
    'smtpUser': smtpUser,
    'fromEmail': fromEmail,
    'sendVia': sendVia,
    'outlookSimple': outlookSimple,
  };

  factory PlannerSettings.fromJson(Map<String, dynamic> j) {
    final d = PlannerSettings();
    return PlannerSettings(
      enabled: j['enabled'] ?? d.enabled,
      to: j['to'] ?? d.to,
      cc: j['cc'] ?? d.cc,
      signature: j['signature'] ?? d.signature,
      planReminder: j['planReminder'] ?? d.planReminder,
      planHour: j['planHour'] ?? d.planHour,
      planMinute: j['planMinute'] ?? d.planMinute,
      eodReminder: j['eodReminder'] ?? d.eodReminder,
      eodHour: j['eodHour'] ?? d.eodHour,
      eodMinute: j['eodMinute'] ?? d.eodMinute,
      smtpHost: j['smtpHost'] ?? d.smtpHost,
      smtpPort: j['smtpPort'] ?? d.smtpPort,
      smtpSsl: j['smtpSsl'] ?? d.smtpSsl,
      smtpUser: j['smtpUser'] ?? d.smtpUser,
      fromEmail: j['fromEmail'] ?? d.fromEmail,
      sendVia: j['sendVia'] ?? d.sendVia,
      outlookSimple: j['outlookSimple'] ?? d.outlookSimple,
    );
  }
}

class Recipient {
  final String name, email;
  Recipient(this.name, this.email);
}

/// Parses "a@x.com, Priya Nair <priya@x.com>; b@x.com".
/// If no display name is given, one is derived from the email
/// (ravi.kumar@x.com -> Ravi).
List<Recipient> parseRecipients(String raw) {
  final out = <Recipient>[];
  for (final part in raw.split(RegExp(r'[;,]'))) {
    final t = part.trim();
    if (t.isEmpty) continue;
    String name = '', email;
    final m = RegExp(r'^(.*?)<([^>]+)>$').firstMatch(t);
    if (m != null) {
      email = m.group(2)!.trim();
      name = m.group(1)!.trim().replaceAll('"', '');
    } else {
      email = t;
    }
    if (!email.contains('@')) continue;
    if (name.isEmpty) {
      final local = email.split('@').first;
      final first = local.split(RegExp(r'[._-]')).first;
      final base = first.isEmpty ? local : first;
      name = base[0].toUpperCase() + base.substring(1);
    }
    out.add(Recipient(name, email));
  }
  return out;
}

String greetingFor(String toRaw) {
  final names = parseRecipients(toRaw).map((r) => r.name).toList();
  if (names.isEmpty) return 'Team';
  if (names.length == 1) return names.first;
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}
