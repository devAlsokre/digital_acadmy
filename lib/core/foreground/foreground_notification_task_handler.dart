import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../background/background_notification_poller.dart';
import '../background/background_session_store.dart';
import '../services/local_notification_service.dart';

@pragma('vm:entry-point')
void startForegroundNotificationTask() {
  FlutterForegroundTask.setTaskHandler(
    ForegroundNotificationTaskHandler(),
  );
}

class ForegroundNotificationTaskHandler extends TaskHandler {
  static const BackgroundSessionStore _sessionStore = BackgroundSessionStore();
  static const BackgroundNotificationPoller _poller =
      BackgroundNotificationPoller(sessionStore: _sessionStore);

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    await LocalNotificationService.initialize();

    if (kDebugMode) {
      debugPrint('Foreground notification service task started.');
    }

    await _pollOnce();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _pollOnce();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    if (kDebugMode) {
      debugPrint('Foreground notification service task destroyed.');
    }
  }

  Future<void> _pollOnce() async {
    try {
      final BackgroundStudentSession? session =
          await _sessionStore.loadStudentBackgroundSession();

      if (session == null || !session.canPoll) {
        if (kDebugMode) {
          debugPrint('Foreground poll skipped: no valid student session.');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('Foreground poll tick.');
      }

      await _poller.pollAndNotify(session, source: 'foreground_service');
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Foreground notification polling failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}
