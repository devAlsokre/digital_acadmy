import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'foreground_notification_service.dart';
import 'foreground_notification_task_handler.dart';

final Provider<ForegroundServiceController>
    foregroundServiceControllerProvider =
    Provider<ForegroundServiceController>((ref) {
  return const ForegroundServiceController();
});

class ForegroundServiceController {
  const ForegroundServiceController();

  static bool _startRequestInProgress = false;
  static DateTime? _lastStartRequestAt;

  Future<bool> isNotificationServiceRunning() async {
    if (!Platform.isAndroid) {
      return false;
    }

    return FlutterForegroundTask.isRunningService;
  }

  Future<void> startNotificationService() async {
    if (!Platform.isAndroid) {
      return;
    }

    if (_startRequestInProgress) {
      if (kDebugMode) {
        debugPrint(
          'FOREGROUND_SERVICE_START_SKIPPED_ALREADY_RUNNING reason=request_in_progress',
        );
      }
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime? lastStartRequestAt = _lastStartRequestAt;
    if (lastStartRequestAt != null &&
        now.difference(lastStartRequestAt) < const Duration(seconds: 10)) {
      if (kDebugMode) {
        debugPrint(
          'FOREGROUND_SERVICE_START_SKIPPED_ALREADY_RUNNING reason=recent_start_request',
        );
      }
      return;
    }

    _startRequestInProgress = true;

    ForegroundNotificationService.initialize();
    await ForegroundNotificationService.requestPermissionIfNeeded();

    try {
      final bool isRunning = await FlutterForegroundTask.isRunningService;

      if (isRunning) {
        if (kDebugMode) {
          debugPrint(
            'FOREGROUND_SERVICE_START_SKIPPED_ALREADY_RUNNING',
          );
        }

        return;
      }

      _lastStartRequestAt = now;

      if (kDebugMode) {
        debugPrint('FOREGROUND_SERVICE_START_REQUESTED');
      }

      final ServiceRequestResult result =
          await FlutterForegroundTask.startService(
        serviceId: ForegroundNotificationService.serviceId,
        notificationTitle: ForegroundNotificationService.notificationTitle,
        notificationText: ForegroundNotificationService.notificationText,
        callback: startForegroundNotificationTask,
      );

      if (kDebugMode) {
        debugPrint('Foreground notification service start requested: $result');
      }
    } finally {
      _startRequestInProgress = false;
    }
  }

  Future<void> stopNotificationService() async {
    if (!Platform.isAndroid) {
      return;
    }

    final bool isRunning = await FlutterForegroundTask.isRunningService;

    if (!isRunning) {
      return;
    }

    final ServiceRequestResult result =
        await FlutterForegroundTask.stopService();

    if (kDebugMode) {
      debugPrint('Foreground notification service stopped: $result');
    }
  }
}
