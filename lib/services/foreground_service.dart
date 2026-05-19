import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

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
  StreamSubscription<Position>? _locationSubscription;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Démarrer la géoloc ici, dans le service natif
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // mètres
      ),
    ).listen((Position position) {
      // Envoyer la position au thread Flutter (map_screen)
      FlutterForegroundTask.sendDataToMain({
        'lat': position.latitude,
        'lng': position.longitude,
      });
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Peut rester vide ou servir à un heartbeat de log
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _locationSubscription?.cancel();
  }
}