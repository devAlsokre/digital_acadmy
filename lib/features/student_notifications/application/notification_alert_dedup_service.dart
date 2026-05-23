import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/background/background_session_store.dart';

final Provider<NotificationAlertDedupService>
    notificationAlertDedupServiceProvider =
    Provider<NotificationAlertDedupService>((ref) {
  return NotificationAlertDedupService(const BackgroundSessionStore());
});

class NotificationAlertDedupService {
  NotificationAlertDedupService(this._sessionStore);

  final BackgroundSessionStore _sessionStore;
  final Set<String> _memoryAlertedIds = <String>{};
  final Set<String> _memoryReadIds = <String>{};

  Future<bool> shouldAlert({
    required String notificationId,
    required bool isRead,
  }) async {
    final String cleanId = notificationId.trim();

    if (cleanId.isEmpty || isRead || _memoryReadIds.contains(cleanId)) {
      if (kDebugMode && isRead) {
        debugPrint('Local alert skipped because notification is already read.');
      }
      return false;
    }

    if (_memoryAlertedIds.contains(cleanId)) {
      if (kDebugMode) {
        debugPrint(
          'Local alert skipped because notification was already alerted in memory.',
        );
      }
      return false;
    }

    final BackgroundStudentSession? session =
        await _sessionStore.loadStudentBackgroundSession();

    if (session == null) {
      return true;
    }

    if (session.readNotificationIds.contains(cleanId)) {
      if (kDebugMode) {
        debugPrint('Local alert skipped because notification is cached read.');
      }
      return false;
    }

    if (session.alertedNotificationIds.contains(cleanId)) {
      if (kDebugMode) {
        debugPrint(
          'Local alert skipped because notification was already alerted.',
        );
      }
      return false;
    }

    return true;
  }

  Future<void> markAlerted(String notificationId) async {
    final String cleanId = notificationId.trim();
    if (cleanId.isEmpty) {
      return;
    }

    _memoryAlertedIds.add(cleanId);
    await _sessionStore.addAlertedNotificationId(notificationId);

    if (kDebugMode) {
      debugPrint('Notification alert cache updated after local alert.');
    }
  }

  Future<void> markRead(String notificationId) async {
    final String cleanId = notificationId.trim();
    if (cleanId.isEmpty) {
      return;
    }

    _memoryReadIds.add(cleanId);
    _memoryAlertedIds.add(cleanId);
    await _sessionStore.addReadNotificationId(notificationId);

    if (kDebugMode) {
      debugPrint('Notification read cache updated.');
    }
  }
}
