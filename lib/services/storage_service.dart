import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

class StorageService {
  static const _secure = FlutterSecureStorage();

  // ---------- Credentials (secure) ----------
  static Future<void> saveCredentials(Credentials c) async {
    await _secure.write(key: 'url', value: c.url);
    await _secure.write(key: 'email', value: c.email);
    await _secure.write(key: 'token', value: c.token);
    await _secure.write(key: 'accountId', value: c.accountId);
  }

  static Future<Credentials?> credentials() async {
    final url = await _secure.read(key: 'url');
    final email = await _secure.read(key: 'email');
    final token = await _secure.read(key: 'token');
    final id = await _secure.read(key: 'accountId');
    if (url == null || email == null || token == null || id == null) return null;
    return Credentials(url, email, token, id);
  }

  static Future<void> disconnect() async {
    await _secure.deleteAll();
    final p = await SharedPreferences.getInstance();
    await p.remove('lastCheckedDate');
  }

  // ---------- Reminder settings ----------
  static Future<void> saveSettings(ReminderSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('hour', s.hour);
    await p.setInt('minute', s.minute);
    await p.setStringList('days', s.weekdays.map((e) => '$e').toList());
    await p.setDouble('minHours', s.minHours);
    await p.remove('lastCheckedDate'); // allow re-check with the new time
  }

  static Future<ReminderSettings> loadSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // needed when called from a background isolate
    final d = ReminderSettings();
    return ReminderSettings(
      hour: p.getInt('hour') ?? d.hour,
      minute: p.getInt('minute') ?? d.minute,
      weekdays: p.getStringList('days')?.map(int.parse).toList() ?? d.weekdays,
      minHours: p.getDouble('minHours') ?? d.minHours,
    );
  }

  // ---------- "Already handled today" flag ----------
  static Future<String?> lastCheckedDate() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p.getString('lastCheckedDate');
  }

  static Future<void> setLastCheckedDate(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('lastCheckedDate', v);
  }

  // ---------- First-run flag ----------
  static Future<bool> hasOnboarded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('onboarded') ?? false;
  }

  static Future<void> setOnboarded() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarded', true);
  }
}
