import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/planner.dart';
import '../models/settings.dart';

class PlannerStorage {
  static const _secure = FlutterSecureStorage();

  // ---------- Settings ----------
  static Future<PlannerSettings> loadSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final raw = p.getString('planner');
    if (raw == null) return PlannerSettings();
    try {
      return PlannerSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return PlannerSettings();
    }
  }

  static Future<void> saveSettings(PlannerSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('planner', jsonEncode(s.toJson()));
    // allow reminders to fire again after a time change
    await p.remove('notified_plan');
    await p.remove('notified_eod');
  }

  // ---------- SMTP password (secure) ----------
  static Future<String> loadPassword() async =>
      await _secure.read(key: 'smtpPass') ?? '';

  static Future<void> savePassword(String v) =>
      _secure.write(key: 'smtpPass', value: v);

  // ---------- Today's plan ----------
  static Future<DayPlan> loadDay() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final today = dateKey(DateTime.now());
    final raw = p.getString('dayPlan');
    if (raw != null) {
      try {
        final d = DayPlan.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
        if (d.date == today) return d;
      } catch (_) {}
    }
    return DayPlan(date: today);
  }

  static Future<void> saveDay(DayPlan d) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('dayPlan', jsonEncode(d.toJson()));
  }

  // ---------- "Reminder already shown today" flags ----------
  static Future<bool> notifiedToday(String kind) async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p.getString('notified_$kind') == dateKey(DateTime.now());
  }

  static Future<void> markNotified(String kind) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('notified_$kind', dateKey(DateTime.now()));
  }
}
