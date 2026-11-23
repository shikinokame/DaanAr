import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages local push notifications for landmark arrival alerts.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;
  Future<void>? _permissionRequest;

  static const _channelId = 'daanar_geofence';
  static const _channelName = 'Landmark Alerts';
  static const _channelDesc =
      'Notifies you when you arrive near a heritage landmark.';

  /// Called when nearby landmark alerts start.
  Future<void> enableArrivalAlerts() =>
      _permissionRequest ??= _requestArrivalAlerts();

  Future<void> _requestArrivalAlerts() async {
    await (_initialization ??= _init());
    await Permission.notification.request();
  }

  Future<void> _init() async {
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
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Show a "You arrived!" notification for a landmark.
  Future<void> showArrivalNotification({
    required int id,
    required String landmarkName,
    required String municipality,
  }) async {
    if (!await Permission.notification.isGranted) return;
    await (_initialization ??= _init());
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
      'Landmark Nearby',
      '$landmarkName, $municipality. Tap to view in AR.',
      const NotificationDetails(android: androidDetails),
    );
  }
}
