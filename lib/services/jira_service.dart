import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/settings.dart';
import '../models/worklog_entry.dart';
import 'package:flutter/foundation.dart';
import '../models/planner.dart';
import '../utils/format.dart';

class JiraService {
  late final Dio _dio;

  JiraService(String baseUrl, String email, String token) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl.replaceAll(RegExp(r'/+$'), ''),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$email:$token'))}',
        'Accept': 'application/json',
      },
    ));
  }

  /// Validates credentials; returns the user profile (contains accountId).
  Future<Map<String, dynamic>> myself() async {
    try {
      final response = await _dio.get(
        '/rest/api/3/myself',
        options: Options(responseType: ResponseType.plain),
      );

      debugPrint('Status: ${response.statusCode}');
      debugPrint('Response: ${response.data}');

      final data = jsonDecode(response.data as String);

      return Map<String, dynamic>.from(data as Map);
    } catch (e, stackTrace) {
      debugPrint('Jira error: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Total seconds the current user logged on [day].
  Future<int> secondsLoggedOn(DateTime day, String accountId) async {
    final d = dateKey(day);

    final res = await _dio.get('/rest/api/3/search/jql', queryParameters: {
      'jql': 'worklogAuthor = currentUser() AND worklogDate = "$d"',
      'fields': 'summary',
      'maxResults': 100,
    });

    int total = 0;
    for (final issue in (res.data['issues'] as List)) {
      final wl = await _dio.get('/rest/api/3/issue/${issue['key']}/worklog');
      for (final w in (wl.data['worklogs'] as List)) {
        final isMine = w['author']?['accountId'] == accountId;
        final started = (w['started'] as String).substring(0, 10);
        if (isMine && started == d) total += (w['timeSpentSeconds'] as int);
      }
    }
    return total;
  }

  Future<List<WorklogEntry>> worklogsBetween(
      DateTime from, DateTime to, String accountId) async {
    final f = dateKey(from), t = dateKey(to);
    final jql =
        'worklogAuthor = currentUser() AND worklogDate >= "$f" AND worklogDate <= "$t"';

    // 1. Find issues (follow pagination)
    final issues = <Map<String, dynamic>>[];
    String? pageToken;
    do {
      final res = await _dio.get('/rest/api/3/search/jql', queryParameters: {
        'jql': jql,
        'fields': 'summary',
        'maxResults': 100,
        'nextPageToken': ?pageToken,
      });
      issues.addAll((res.data['issues'] as List).cast<Map<String, dynamic>>());
      pageToken = res.data['isLast'] == true
          ? null
          : res.data['nextPageToken'] as String?;
    } while (pageToken != null);

    // 2. Fetch each issue's worklogs, 5 at a time
    final entries = <WorklogEntry>[];
    for (var i = 0; i < issues.length; i += 5) {
      final chunk = issues.skip(i).take(5);
      final results = await Future.wait(chunk.map((issue) async {
        final key = issue['key'] as String;
        final summary = (issue['fields']?['summary'] ?? '') as String;
        final wl = await _dio.get('/rest/api/3/issue/$key/worklog',
            queryParameters: {'maxResults': 1000});
        final list = <WorklogEntry>[];
        for (final w in (wl.data['worklogs'] as List)) {
          if (w['author']?['accountId'] != accountId) continue;
          final started = (w['started'] as String).substring(0, 10);
          if (started.compareTo(f) < 0 || started.compareTo(t) > 0) continue;
          final p = started.split('-').map(int.parse).toList();
          list.add(WorklogEntry(
            issueKey: key,
            summary: summary,
            date: DateTime(p[0], p[1], p[2]),
            seconds: w['timeSpentSeconds'] as int,
            comment: _adfText(w['comment']).trim(),
          ));
        }
        return list;
      }));
      for (final r in results) {
        entries.addAll(r);
      }
    }
    return entries;
  }

  /// Worklog comments come as Atlassian Document Format (nested JSON).
  String _adfText(dynamic node) {
    if (node is Map) {
      if (node['type'] == 'text') return (node['text'] ?? '') as String;
      final c = node['content'];
      if (c is List) return c.map(_adfText).join(' ');
    }
    return '';
  }

  /// Default (empty query): my To Do / In Progress tasks, highest priority first.
  /// "ABC-123": exact key (any assignee). Anything else: text search.
  Future<List<JiraIssue>> searchIssues(String query) async {
    final q = query.trim();
    String jql;
    if (q.isEmpty) {
      jql = 'assignee = currentUser() AND statusCategory in ("To Do", "In Progress") '
          'ORDER BY priority DESC, updated DESC';
    } else if (RegExp(r'^[A-Za-z][A-Za-z0-9_]*-\d+$').hasMatch(q)) {
      jql = 'key = "${q.toUpperCase()}"';
    } else {
      final safe = q.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      jql = 'text ~ "$safe*" ORDER BY updated DESC';
    }
    final res = await _dio.get('/rest/api/3/search/jql', queryParameters: {
      'jql': jql,
      'fields': 'summary,status,priority',
      'maxResults': 30,
    });
    return (res.data['issues'] as List).map((i) {
      final f = i['fields'] as Map<String, dynamic>;
      return JiraIssue(
        i['key'] as String,
        (f['summary'] ?? '') as String,
        (f['status']?['name'] ?? '') as String,
        (f['priority']?['name'] ?? '-') as String,
      );
    }).toList();
  }

  /// Adds a worklog with an optional description.
  Future<void> addWorklog(
      String issueKey, int seconds, DateTime started, String comment) async {
    await _dio.post('/rest/api/3/issue/$issueKey/worklog', data: {
      'timeSpentSeconds': seconds < 60 ? 60 : seconds,
      'started': jiraStarted(started),
      if (comment.trim().isNotEmpty)
        'comment': {
          'type': 'doc',
          'version': 1,
          'content': [
            {
              'type': 'paragraph',
              'content': [
                {'type': 'text', 'text': comment.trim()}
              ]
            }
          ]
        },
    });
  }
}
