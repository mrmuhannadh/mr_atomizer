import 'dart:io';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Keeps the app alive in the system tray so the timer keeps running.
class DesktopService with TrayListener, WindowListener {
  static final DesktopService _i = DesktopService._();
  DesktopService._();

  static Future<void> init() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(_i);

    await trayManager.setIcon(
        Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Open Jira Notifier'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
    trayManager.addListener(_i);

    launchAtStartup.setup(
        appName: 'Jira Notifier', appPath: Platform.resolvedExecutable);
    await launchAtStartup.enable();
  }

  @override
  void onWindowClose() async => await windowManager.hide(); // hide, don't quit

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'quit') {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    }
  }
}
