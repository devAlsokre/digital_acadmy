import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundNotificationService {
  const ForegroundNotificationService._();

  static const int serviceId = 1042;
  static const String channelId =
      'digital_academy_foreground_service_silent_v6';
  static const String channelName = 'Digital Academy Background Service';
  static const String channelDescription =
      'Keeps local university notification checks running.';
  static const String notificationTitle = 'Digital Academy';
  static const String notificationText =
      'Listening for university notifications';

  static void initialize() {
    if (!Platform.isAndroid) {
      return;
    }

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: channelId,
        channelName: channelName,
        channelDescription: channelDescription,
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        showBadge: false,
        onlyAlertOnce: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    if (kDebugMode) {
      debugPrint(
        'Foreground service notification channel initialized as silent.',
      );
    }
  }

  static Future<void> requestPermissionIfNeeded() async {
    if (!Platform.isAndroid) {
      return;
    }

    final NotificationPermission permission =
        await FlutterForegroundTask.checkNotificationPermission();

    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }
}
