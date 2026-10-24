class Credentials {
  final String url, email, token, accountId;
  Credentials(this.url, this.email, this.token, this.accountId);
}

class ReminderSettings {
  int hour;
  int minute;
  List<int> weekdays; // DateTime.monday (1) ... DateTime.sunday (7)
  double minHours;

  ReminderSettings({
    this.hour = 16,
    this.minute = 30,
    this.weekdays = const [1, 2, 3, 4, 5],
    this.minHours = 8,
  });
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
