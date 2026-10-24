import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jira_manager/theme/glass_theme.dart';
import 'screens/connect_screen.dart';
import 'screens/home_screen.dart';
import 'services/background_service.dart';
import 'services/desktop_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  if (Platform.isAndroid) await startAndroidWorker();
  if (isDesktop) {
    await DesktopService.init();
    startDesktopTimer();
  }

  final connected = await StorageService.credentials() != null;
  final onboarded = await StorageService.hasOnboarded();

  runApp(JiraNotifierApp(connected: connected, onboarded: onboarded));
}

class JiraNotifierApp extends StatelessWidget {
  final bool connected, onboarded;
  const JiraNotifierApp({
    super.key,
    required this.connected,
    required this.onboarded,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Jira Notifier',
    theme: GlassTheme.light(),
    darkTheme: GlassTheme.dark(),
    themeMode: ThemeMode.system,
    debugShowCheckedModeBanner: false,
    home: connected
        ? const HomeScreen()
        : (onboarded ? const ConnectScreen() : const WelcomeScreen()),
  );
}
