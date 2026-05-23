import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  const LocalNotificationService._();

  static const String channelId = 'digital_academy_student_alerts_v2';
  static const String channelName = 'Digital Academy Alerts';
  static const String channelDescription =
      'Important university notification alerts';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(settings);

    const AndroidNotificationChannel androidChannel =
        AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      showBadge: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _isInitialized = true;
  }

  static Future<void> requestForegroundPermissions() async {
    await initialize();

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> showStudentNotification({
    required int id,
    required String title,
    required String body,
    String source = 'unknown',
    String? notificationKey,
    String reason = 'new_unread',
    int? unreadCount,
  }) async {
    final String cleanNotificationKey = notificationKey?.trim() ?? '';

    if (cleanNotificationKey.isEmpty) {
      _logBlockedShow(source, cleanNotificationKey, 'missing_notification_id');
      return;
    }

    if (reason != 'new_unread') {
      _logBlockedShow(source, cleanNotificationKey, 'invalid_reason');
      return;
    }

    if (unreadCount != null && unreadCount <= 0) {
      _logBlockedShow(source, cleanNotificationKey, 'unread_count_zero');
      return;
    }

    await initialize();

    if (kDebugMode) {
      debugPrint(
        'SHOW_NOTIFICATION source=$source id=$cleanNotificationKey title=$title reason=$reason unread_count=${unreadCount ?? 'unknown'}',
      );
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      channelShowBadge: false,
      onlyAlertOnce: true,
    );
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
    await _plugin.show(
      id,
      title,
      body,
      details,
    );

    if (kDebugMode) {
      debugPrint('Local notification shown for unread student notification.');
    }
  }

  static Future<void> cancelStudentNotification(String notificationKey) async {
    final String cleanNotificationKey = notificationKey.trim();

    if (cleanNotificationKey.isEmpty) {
      return;
    }

    await initialize();

    final int id = stableNotificationId(cleanNotificationKey);
    await _plugin.cancel(id);

    if (kDebugMode) {
      debugPrint('STUDENT_ALERT_CANCELLED id=$cleanNotificationKey');
    }
  }

  static int stableNotificationId(String value) {
    const int fnvPrime = 16777619;
    const int fnvOffsetBasis = 2166136261;
    int hash = fnvOffsetBasis;

    for (final int codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }

    final int id = hash & 0x7fffffff;

    if (kDebugMode) {
      debugPrint('STABLE_NOTIFICATION_ID id=$value stableId=$id');
    }

    return id;
  }

  static void _logBlockedShow(
    String source,
    String notificationKey,
    String reason,
  ) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      'BLOCKED_SHOW_NOTIFICATION reason=$reason source=$source id=${notificationKey.isEmpty ? 'unknown' : notificationKey}',
    );
  }
}
