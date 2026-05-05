import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundServiceManager {
  static void initialiser() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'fayow_channel',
        channelName: 'FaYoW',
        channelDescription: 'FaYoW est actif',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  static Future<void> demarrer() async {
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      serviceId: 1,
      notificationTitle: 'FaYoW',
      notificationText: 'Détection des points d\'intérêt active',
      callback: startCallback,
    );
  }

  static Future<void> arreter() async {
    await FlutterForegroundTask.stopService();
  }
}

// Cette fonction doit être top-level (hors de toute classe)
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(FayowTaskHandler());
}

class FayowTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('Foreground service démarré');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Événement répété toutes les 5 secondes
    // La détection GPS est gérée dans map_screen.dart via geolocator
    // Ce service sert uniquement à maintenir l'appli active en arrière-plan
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('Foreground service arrêté');
  }
}