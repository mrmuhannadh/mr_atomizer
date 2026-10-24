import 'dart:async';
import 'dart:io';
import 'package:workmanager/workmanager.dart';
import '../models/settings.dart';
import 'jira_service.dart';
import 'notification_service.dart';
import 'planner_storage.dart';
import 'storage_service.dart';

/// Hours logged today, or null if not connected / request failed.
Future<double?> fetchTodayHours() async {
  final c = await StorageService.credentials();
  if (c == null) return null;
  try {
    final secs = await JiraService(c.url, c.email, c.token)
        .secondsLoggedOn(DateTime.now(), c.accountId);
    return secs / 3600;
  } catch (_) {
    return null;
  }
}

/// Worklog reminder: once per day, after the reminder time, if hours are short.
Future<void> runScheduledCheck() async {
  final now = DateTime.now();
  final s = await StorageService.loadSettings();

  if (!s.weekdays.contains(now.weekday)) return;

  final reminderPassed =
      now.hour > s.hour || (now.hour == s.hour && now.minute >= s.minute);
  if (!reminderPassed) return;

  final today = dateKey(now);
  if (await StorageService.lastCheckedDate() == today) return;

  final hours = await fetchTodayHours();
  if (hours == null) return; // not connected or request failed: retry next run

  if (hours < s.minHours) {
    await NotificationService.showNow('Log your time ⏰',
        'You have logged only ${hours.toStringAsFixed(1)}h today (goal ${s.minHours.toStringAsFixed(0)}h).');
  }
  await StorageService.setLastCheckedDate(today);
}

bool _passed(DateTime now, int h, int m) =>
    now.hour > h || (now.hour == h && now.minute >= m);

/// Plan / EoD reminders: Mon-Fri, once per day each, only if not yet sent.
Future<void> runPlannerChecks() async {
  final p = await PlannerStorage.loadSettings();
  if (!p.enabled) return;
  final now = DateTime.now();
  if (now.weekday > 5) return;

  final day = await PlannerStorage.loadDay();

  if (p.planReminder &&
      !day.planSent &&
      _passed(now, p.planHour, p.planMinute) &&
      !await PlannerStorage.notifiedToday('plan')) {
    await NotificationService.showNow('Send your task plan 📝',
        "Pick today's Jira tasks and email the plan.",
        id: 31);
    await PlannerStorage.markNotified('plan');
  }

  if (p.eodReminder &&
      !day.eodSent &&
      _passed(now, p.eodHour, p.eodMinute) &&
      !await PlannerStorage.notifiedToday('eod')) {
    await NotificationService.showNow('Send your EoD 📬',
        'Set the time you worked and send the EoD email.',
        id: 32);
    await PlannerStorage.markNotified('eod');
  }
}

// ---------------- Android: WorkManager ----------------
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    await NotificationService.init();
    await runScheduledCheck();
    await runPlannerChecks();
    return true;
  });
}

Future<void> startAndroidWorker() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'worklog-check',
    'check',
    frequency: const Duration(minutes: 15), // Android minimum
  );
}

// ---------------- Windows / macOS: in-app timer ----------------
Timer? _desktopTimer;

Future<void> _tick() async {
  await runScheduledCheck();
  await runPlannerChecks();
}

void startDesktopTimer() {
  _desktopTimer?.cancel();
  _tick();
  _desktopTimer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
}

bool get isDesktop => Platform.isWindows || Platform.isMacOS;
