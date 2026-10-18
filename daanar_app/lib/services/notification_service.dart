import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages local push notifications for landmark arrival alerts.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'daanar_geofence';
  static const _channelName = 'Landmark Alerts';
  static const _channelDesc =
      'Notifies you when you arrive near a heritage landmark.';

  /// Call once in main() before runApp.
  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    // Create the notification channel (Android 8+)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request notification permission on Android 13+
    await Permission.notification.request();
  }

  /// Show a "You arrived!" notification for a landmark.
  Future<void> showArrivalNotification({
    required int id,
    required String landmarkName,
    required String municipality,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
      ticker: 'DaanAR',
    );

    await _plugin.show(
      id,
      '📍 You arrived at a landmark!',
      '$landmarkName — $municipality\nTap to explore in AR →',
      const NotificationDetails(android: androidDetails),
    );
  }
}
