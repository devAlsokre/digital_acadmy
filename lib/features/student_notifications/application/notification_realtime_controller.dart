import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/local_notification_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../student_profile/domain/student_profile.dart';
import '../data/student_notifications_repository.dart';
import '../domain/student_notification.dart';
import 'notification_alert_dedup_service.dart';
import 'student_notifications_controller.dart';

final Provider<NotificationRealtimeController>
    notificationRealtimeControllerProvider =
    Provider<NotificationRealtimeController>((ref) {
  final NotificationRealtimeController controller =
      NotificationRealtimeController(
    ref.watch(supabaseServiceProvider),
    ref.watch(studentNotificationsRepositoryProvider),
    ref.watch(notificationAlertDedupServiceProvider),
    ref,
  );

  ref.onDispose(controller.dispose);
  return controller;
});

class NotificationRealtimeController with WidgetsBindingObserver {
  NotificationRealtimeController(
    this._supabaseService,
    this._repository,
    this._dedupService,
    this._ref,
  );

  final SupabaseService _supabaseService;
  final StudentNotificationsRepository _repository;
  final NotificationAlertDedupService _dedupService;
  final Ref _ref;

  RealtimeChannel? _channel;
  StudentProfile? _student;
  List<String> _courseOfferingIds = <String>[];
  bool _isObserverRegistered = false;

  SupabaseClient get _client => _supabaseService.client;

  Future<void> start({
    required StudentProfile student,
    required List<String> courseOfferingIds,
  }) async {
    final bool sameStudent = _student?.id == student.id;
    final bool hasChannel = _channel != null;

    _student = student;
    _courseOfferingIds =
        courseOfferingIds.where((id) => id.isNotEmpty).toSet().toList();

    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverRegistered = true;
    }

    if (sameStudent && hasChannel) {
      return;
    }

    await stop(removeObserver: false);

    final RealtimeChannel channel = _client.channel(
      'student_notifications_${student.id}',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notification_targets',
          callback: _handleNotificationTargetInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notification_reads',
          callback: _handleNotificationReadInsert,
        )
        .subscribe((status, error) {
      if (kDebugMode) {
        debugPrint('Notification realtime status: $status');
        if (error != null) {
          debugPrint('Notification realtime subscription error: $error');
        }
      }
    });

    _channel = channel;

    if (kDebugMode) {
      debugPrint('Notification realtime subscription started.');
    }
  }

  Future<void> stop({bool removeObserver = true}) async {
    final RealtimeChannel? channel = _channel;
    _channel = null;

    if (channel != null) {
      await _client.removeChannel(channel);

      if (kDebugMode) {
        debugPrint('Notification realtime channel disposed.');
      }
    }

    if (removeObserver && _isObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverRegistered = false;
    }
  }

  void dispose() {
    stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final StudentProfile? student = _student;
    if (student == null) {
      return;
    }

    if (kDebugMode) {
      debugPrint('Notification realtime resubscribing after app resume.');
    }

    _handleResume(student);
  }

  Future<void> _handleResume(StudentProfile student) async {
    try {
      await start(student: student, courseOfferingIds: _courseOfferingIds);
      await _ref
          .read(studentNotificationsControllerProvider.notifier)
          .loadNotifications(force: true);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Notification realtime resume refresh failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> _handleNotificationTargetInsert(
    PostgresChangePayload payload,
  ) async {
    final StudentProfile? student = _student;
    if (student == null) {
      return;
    }

    final Map<String, dynamic> target = payload.newRecord;
    final String notificationId = _asString(target['notification_id']);

    if (kDebugMode) {
      debugPrint('notification_targets INSERT received.');
    }

    if (notificationId.isEmpty) {
      return;
    }

    final bool matches = _matchesTarget(target, student, _courseOfferingIds);

    if (kDebugMode) {
      debugPrint(matches ? 'Notification target matched.' : 'Target skipped.');
    }

    if (!matches) {
      return;
    }

    try {
      final StudentNotification? notification =
          await _repository.getNotificationById(
        notificationId: notificationId,
        studentId: student.id,
      );

      if (notification == null) {
        return;
      }

      if (kDebugMode) {
        debugPrint('Realtime notification fetched.');
        debugPrint('Realtime notification read check: ${notification.isRead}');
      }

      _ref
          .read(studentNotificationsControllerProvider.notifier)
          .addOrUpdateNotification(notification);

      if (notification.isRead) {
        if (kDebugMode) {
          debugPrint(
            'SKIP_STUDENT_ALERT source=realtime id=${notification.id} reason=already_read',
          );
        }
        await _dedupService.markRead(notification.id);
        return;
      }

      final bool shouldAlert = await _dedupService.shouldAlert(
        notificationId: notification.id,
        isRead: notification.isRead,
      );

      if (!shouldAlert) {
        if (kDebugMode) {
          debugPrint(
            'SKIP_STUDENT_ALERT source=realtime id=${notification.id} reason=already_read_or_alerted',
          );
        }
        return;
      }

      if (notification.id.trim().isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'SKIP_STUDENT_ALERT source=realtime id=unknown reason=missing_notification_id',
          );
        }
        return;
      }

      const int unreadCount = 1;

      if (unreadCount <= 0) {
        if (kDebugMode) {
          debugPrint(
            'SKIP_STUDENT_ALERT source=realtime id=${notification.id} reason=unread_count_zero',
          );
        }
        return;
      }

      if (kDebugMode) {
        debugPrint(
          'ABOUT_TO_SHOW_STUDENT_ALERT source=realtime id=${notification.id} unreadCount=$unreadCount',
        );
      }

      await LocalNotificationService.showStudentNotification(
        id: LocalNotificationService.stableNotificationId(notification.id),
        title: notification.title,
        body: notification.body.isEmpty
            ? 'You have a new university notification.'
            : notification.body,
        source: 'realtime',
        notificationKey: notification.id,
        reason: 'new_unread',
        unreadCount: unreadCount,
      );
      await _dedupService.markAlerted(notification.id);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Realtime notification handling failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> _handleNotificationReadInsert(
    PostgresChangePayload payload,
  ) async {
    final StudentProfile? student = _student;
    if (student == null) {
      return;
    }

    final Map<String, dynamic> read = payload.newRecord;
    final String studentId = _asString(read['student_id']);
    final String notificationId = _asString(read['notification_id']);

    if (kDebugMode) {
      debugPrint('notification_reads INSERT received.');
    }

    if (studentId != student.id || notificationId.isEmpty) {
      return;
    }

    final DateTime? readAt = DateTime.tryParse(
      _asString(read['read_at']),
    )?.toLocal();

    _ref
        .read(studentNotificationsControllerProvider.notifier)
        .markLocalAsRead(notificationId, readAt: readAt);
    await _dedupService.markRead(notificationId);
    await LocalNotificationService.cancelStudentNotification(notificationId);
  }

  bool _matchesTarget(
    Map<String, dynamic> target,
    StudentProfile student,
    List<String> courseOfferingIds,
  ) {
    final String targetType = _asString(target['target_type']).toLowerCase();

    if (targetType == 'all') {
      return true;
    }

    if (targetType == 'college') {
      return _matchesNullableId(target['college_id'], student.collegeId);
    }

    if (targetType == 'department') {
      return _matchesNullableId(
        target['department_id'],
        student.departmentId,
      );
    }

    if (targetType == 'major') {
      return _matchesNullableId(target['major_id'], student.majorId);
    }

    if (targetType == 'level') {
      return _matchesNullableId(target['level_id'], student.levelId);
    }

    if (targetType == 'batch') {
      return _matchesNullableId(target['batch_id'], student.batchId);
    }

    if (targetType == 'section') {
      return _matchesNullableId(target['section_id'], student.sectionId);
    }

    if (targetType == 'student') {
      return _matchesNullableId(target['student_id'], student.id);
    }

    if (targetType == 'course' || targetType == 'course_offering') {
      return courseOfferingIds
          .contains(_asString(target['course_offering_id']));
    }

    return _matchesNullableId(target['college_id'], student.collegeId) ||
        _matchesNullableId(target['department_id'], student.departmentId) ||
        _matchesNullableId(target['major_id'], student.majorId) ||
        _matchesNullableId(target['level_id'], student.levelId) ||
        _matchesNullableId(target['batch_id'], student.batchId) ||
        _matchesNullableId(target['section_id'], student.sectionId) ||
        _matchesNullableId(target['student_id'], student.id) ||
        courseOfferingIds.contains(_asString(target['course_offering_id']));
  }

  bool _matchesNullableId(Object? targetValue, String? studentValue) {
    final String target = _asString(targetValue);
    return target.isNotEmpty && studentValue != null && target == studentValue;
  }

  String _asString(Object? value) => value?.toString().trim() ?? '';
}
