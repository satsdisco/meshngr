import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class MeshForegroundService {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mesh_connection',
        channelName: 'Mesh Connection',
        channelDescription: 'Keeps your radio connection alive',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<void> start({String radioName = 'radio'}) async {
    await FlutterForegroundTask.startService(
      notificationTitle: 'meshngr',
      notificationText: 'Connected to $radioName',
      callback: _taskCallback,
    );
  }

  static Future<void> updateNotification(String text) async {
    FlutterForegroundTask.updateService(
      notificationTitle: 'meshngr',
      notificationText: text,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void _taskCallback() {
  FlutterForegroundTask.setTaskHandler(_MeshTaskHandler());
}

class _MeshTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
