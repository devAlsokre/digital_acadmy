import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../services/local_notification_service.dart';
import 'background_notification_poller.dart';
import 'background_session_store.dart';
import 'background_task_names.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      WidgetsFlutterBinding.ensureInitialized();

      if (kDebugMode) {
        debugPrint('Background polling task executed: $task');
      }

      if (task != BackgroundTaskNames.notificationPollingTask &&
          task != Workmanager.iOSBackgroundTask) {
        return true;
      }

      await LocalNotificationService.initialize();

      const BackgroundSessionStore sessionStore = BackgroundSessionStore();
      final BackgroundStudentSession? session =
          await sessionStore.loadStudentBackgroundSession();

      if (session == null || !session.canPoll) {
        if (kDebugMode) {
          debugPrint('No valid background notification session found.');
        }
        return true;
      }

      await const BackgroundNotificationPoller(
        sessionStore: sessionStore,
      ).pollAndNotify(session, source: 'workmanager');

      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Background notification polling failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      return true;
    }
  });
}
