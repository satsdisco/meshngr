import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _enabled = true;

  bool get enabled => _enabled;
  set enabled(bool val) => _enabled = val;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _initialized = true;

    // Request notification permission (Android 13+)
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  Future<void> showDmNotification({
    required String senderName,
    required String text,
    required String contactId,
  }) async {
    if (!_enabled || !_initialized) return;

    await _plugin.show(
      id: senderName.hashCode,
      title: senderName,
      body: text,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'dm_messages',
          'Direct Messages',
          channelDescription: 'Notifications for direct messages',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          groupKey: 'dm_$contactId',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showChannelNotification({
    required String channelName,
    required String senderName,
    required String text,
    required String channelId,
  }) async {
    if (!_enabled || !_initialized) return;

    await _plugin.show(
      id: '$channelId$senderName${DateTime.now().millisecondsSinceEpoch}'.hashCode,
      title: '$senderName in $channelName',
      body: text,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_messages',
          'Channel Messages',
          channelDescription: 'Notifications for channel messages',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.message,
          groupKey: 'ch_$channelId',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
