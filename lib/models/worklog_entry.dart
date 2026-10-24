class WorklogEntry {
  final String issueKey;
  final String summary;
  final DateTime date; // date only (no time)
  final int seconds;
  final String comment;

  WorklogEntry({
    required this.issueKey,
    required this.summary,
    required this.date,
    required this.seconds,
    required this.comment,
  });
}