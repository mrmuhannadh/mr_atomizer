import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/settings.dart';
import 'planner_storage.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
        windows: WindowsInitializationSettings(
          appName: 'Jira Notifier',
          appUserModelId: 'com.example.JiraNotifier',
          guid: '6f1d1d5e-3a2b-4c9e-9a53-0c1f6c2b7a10', // generate your own GUID
        ),
      ),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'worklog',
      'Worklog reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  /// ids: 99 = worklog reminder, 31 = plan reminder, 32 = EoD reminder
  static Future<void> showNow(String title, String body, {int id = 99}) =>
      _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
      );

  static Future<void> _scheduleWeekly(
      int id, int weekday, int hour, int minute, String title, String body,
      {bool skipToday = false}) {
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate:
          _nextWeekday(weekday, hour, minute, skipToday: skipToday),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// iOS only: pre-schedules weekly repeating reminders for
  /// (1) the Jira worklog check, (2) the plan email, (3) the EoD email.
  /// Reads planner settings and today's state itself, so callers don't change.
  static Future<void> rescheduleIos(ReminderSettings s,
      {bool skipToday = false}) async {
    if (!Platform.isIOS) return;
    await _plugin.cancelAll();

    for (final wd in s.weekdays) {
      await _scheduleWeekly(wd, wd, s.hour, s.minute, 'Log your time ⏰',
          "You haven't logged ${s.minHours.toStringAsFixed(0)} hours in Jira today.",
          skipToday: skipToday);
    }

    final pl = await PlannerStorage.loadSettings();
    if (!pl.enabled) return;
    final day = await PlannerStorage.loadDay();
    for (var wd = 1; wd <= 5; wd++) {
      if (pl.planReminder) {
        await _scheduleWeekly(10 + wd, wd, pl.planHour, pl.planMinute,
            'Send your task plan 📝', "Pick today's Jira tasks and email the plan.",
            skipToday: day.planSent);
      }
      if (pl.eodReminder) {
        await _scheduleWeekly(20 + wd, wd, pl.eodHour, pl.eodMinute,
            'Send your EoD 📬', 'Set the time you worked and send the EoD email.',
            skipToday: day.eodSent);
      }
    }
  }

  static tz.TZDateTime _nextWeekday(int weekday, int h, int m,
      {bool skipToday = false}) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    while (d.weekday != weekday ||
        d.isBefore(now) ||
        (skipToday &&
            d.year == now.year &&
            d.month == now.month &&
            d.day == now.day)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }
}
