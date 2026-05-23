import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/background/background_session_store.dart';
import '../../../core/background/background_task_names.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/foreground/foreground_service_controller.dart';
import '../../../core/services/local_notification_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../student_dashboard/data/student_dashboard_repository.dart';
import '../../student_dashboard/domain/student_course.dart';
import '../../student_profile/domain/student_profile.dart';
import '../data/student_notifications_repository.dart';
import '../domain/student_notification.dart';
import 'notification_realtime_controller.dart';

final Provider<NotificationBackgroundSyncController>
    notificationBackgroundSyncControllerProvider =
    Provider<NotificationBackgroundSyncController>((ref) {
  return NotificationBackgroundSyncController(
    ref.watch(authRepositoryProvider),
    ref.watch(studentDashboardRepositoryProvider),
    ref.watch(studentNotificationsRepositoryProvider),
    ref.watch(notificationRealtimeControllerProvider),
    ref.watch(foregroundServiceControllerProvider),
    const BackgroundSessionStore(),
  );
});

class NotificationBackgroundSyncController {
  NotificationBackgroundSyncController(
    this._authRepository,
    this._dashboardRepository,
    this._notificationsRepository,
    this._realtimeController,
    this._foregroundServiceController,
    this._sessionStore,
  );

  final AuthRepository _authRepository;
  final StudentDashboardRepository _dashboardRepository;
  final StudentNotificationsRepository _notificationsRepository;
  final NotificationRealtimeController _realtimeController;
  final ForegroundServiceController _foregroundServiceController;
  final BackgroundSessionStore _sessionStore;

  bool _isSyncing = false;
  bool _pollingRegistered = false;
  bool _immediateTaskRegisteredThisSession = false;
  bool _permissionRequestedThisSession = false;
  String? _lastStudentId;
  String? _lastSessionSignature;

  Future<void> syncForStudent(
    StudentProfile student, {
    List<String> enrolledCourseOfferingIds = const <String>[],
  }) async {
    if (!Platform.isAndroid) {
      return;
    }

    if (_isSyncing) {
      if (kDebugMode) {
        debugPrint('SYNC_FOR_STUDENT_SKIPPED_ALREADY_RUNNING');
      }
      return;
    }

    _isSyncing = true;

    if (kDebugMode) {
      debugPrint('SYNC_FOR_STUDENT_START');
    }

    final String accessToken =
        _authRepository.currentSession?.accessToken.trim() ?? '';

    try {
      if (accessToken.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              'Background polling not registered: missing access token.');
        }
        return;
      }

      final List<String> courseOfferingIds = enrolledCourseOfferingIds
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final List<String> resolvedCourseOfferingIds =
          courseOfferingIds.isNotEmpty
              ? courseOfferingIds
              : await _getCourseOfferingIds(student.id);
      final String sessionSignature = _buildSessionSignature(
        student: student,
        accessToken: accessToken,
        courseOfferingIds: resolvedCourseOfferingIds,
      );
      final bool sameSession = _lastStudentId == student.id &&
          _lastSessionSignature == sessionSignature;
      final bool isForegroundRunning =
          await _foregroundServiceController.isNotificationServiceRunning();
      final BackgroundStudentSession? existingSession =
          await _sessionStore.loadStudentBackgroundSession();
      final _NotificationBaseline baseline = await _loadNotificationBaseline(
        student: student,
        courseOfferingIds: resolvedCourseOfferingIds,
      );

      await _sessionStore.saveStudentBackgroundSession(
        BackgroundStudentSession(
          supabaseUrl: SupabaseConfig.initializationUrl,
          supabaseAnonKey: SupabaseConfig.anonKey,
          accessToken: accessToken,
          studentId: student.id,
          collegeId: student.collegeId,
          departmentId: student.departmentId,
          majorId: student.majorId,
          levelId: student.levelId,
          batchId: student.batchId,
          sectionId: student.sectionId,
          enrolledCourseOfferingIds: resolvedCourseOfferingIds,
          alertedNotificationIds: _mergeIds(
            existingSession?.alertedNotificationIds ?? <String>[],
            baseline.visibleNotificationIds,
          ),
          readNotificationIds: _mergeIds(
            existingSession?.readNotificationIds ?? <String>[],
            baseline.readNotificationIds,
          ),
        ),
      );

      if (kDebugMode) {
        debugPrint(
          'Notification startup baseline saved. visible=${baseline.visibleNotificationIds.length} read=${baseline.readNotificationIds.length}',
        );
      }

      if (sameSession && _pollingRegistered && isForegroundRunning) {
        if (kDebugMode) {
          debugPrint('SYNC_FOR_STUDENT_SAME_SESSION_NO_RESTART');
        }
        return;
      }

      if (!_permissionRequestedThisSession) {
        await LocalNotificationService.requestForegroundPermissions();
        _permissionRequestedThisSession = true;
      } else if (kDebugMode) {
        debugPrint('PERMISSION_REQUEST_SKIPPED_ALREADY_REQUESTED');
      }

      await _realtimeController.start(
        student: student,
        courseOfferingIds: resolvedCourseOfferingIds,
      );

      if (isForegroundRunning) {
        if (kDebugMode) {
          debugPrint('FOREGROUND_SERVICE_START_SKIPPED_ALREADY_RUNNING');
        }
      } else {
        await _foregroundServiceController.startNotificationService();
      }

      await _registerPolling();

      _lastStudentId = student.id;
      _lastSessionSignature = sessionSignature;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> cancelPollingAndClearSession() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _foregroundServiceController.stopNotificationService();
      await _realtimeController.stop();
      await _sessionStore.clearStudentBackgroundSession();
      await Workmanager().cancelByUniqueName(
        BackgroundTaskNames.notificationPollingUniqueName,
      );
      await Workmanager().cancelByUniqueName(
        BackgroundTaskNames.notificationPollingImmediateUniqueName,
      );
      _pollingRegistered = false;
      _immediateTaskRegisteredThisSession = false;
      _permissionRequestedThisSession = false;
      _lastStudentId = null;
      _lastSessionSignature = null;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not cancel background notification polling: $error');
      }
    }

    if (kDebugMode) {
      debugPrint('Background notification polling cancelled on logout.');
    }
  }

  Future<void> _registerPolling() async {
    if (_pollingRegistered) {
      if (kDebugMode) {
        debugPrint('WORKMANAGER_PERIODIC_SKIPPED_ALREADY_REGISTERED');
      }
    } else {
      await Workmanager().registerPeriodicTask(
        BackgroundTaskNames.notificationPollingUniqueName,
        BackgroundTaskNames.notificationPollingTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
      _pollingRegistered = true;

      if (kDebugMode) {
        debugPrint('WORKMANAGER_PERIODIC_REGISTERED');
      }
    }

    if (_immediateTaskRegisteredThisSession) {
      if (kDebugMode) {
        debugPrint('WORKMANAGER_IMMEDIATE_SKIPPED_ALREADY_REGISTERED');
      }
      return;
    }

    await Workmanager().registerOneOffTask(
      BackgroundTaskNames.notificationPollingImmediateUniqueName,
      BackgroundTaskNames.notificationPollingTask,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
    _immediateTaskRegisteredThisSession = true;

    if (kDebugMode) {
      debugPrint('WORKMANAGER_IMMEDIATE_REGISTERED');
    }
  }

  Future<List<String>> _getCourseOfferingIds(String studentId) async {
    final List<StudentCourse> courses =
        await _dashboardRepository.getMyCourses(studentId);

    return courses
        .map((course) => course.courseOfferingId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<_NotificationBaseline> _loadNotificationBaseline({
    required StudentProfile student,
    required List<String> courseOfferingIds,
  }) async {
    try {
      final List<StudentNotification> notifications =
          await _notificationsRepository.getMyNotifications(
        student: student,
        courseOfferingIds: courseOfferingIds,
      );

      return _NotificationBaseline(
        visibleNotificationIds: notifications
            .map((notification) => notification.id)
            .where((id) => id.isNotEmpty)
            .toList(),
        readNotificationIds: notifications
            .where((notification) => notification.isRead)
            .map((notification) => notification.id)
            .where((id) => id.isNotEmpty)
            .toList(),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not create notification startup baseline: $error');
      }

      return const _NotificationBaseline(
        visibleNotificationIds: <String>[],
        readNotificationIds: <String>[],
      );
    }
  }

  List<String> _mergeIds(List<String> first, List<String> second) {
    final List<String> merged = <String>{
      ...first.where((id) => id.trim().isNotEmpty),
      ...second.where((id) => id.trim().isNotEmpty),
    }.toList();

    return merged.reversed
        .take(BackgroundSessionStore.maxStoredNotificationIds)
        .toList()
        .reversed
        .toList();
  }

  String _buildSessionSignature({
    required StudentProfile student,
    required String accessToken,
    required List<String> courseOfferingIds,
  }) {
    final List<String> sortedCourseOfferingIds = List<String>.from(
      courseOfferingIds.where((id) => id.trim().isNotEmpty),
    )..sort();

    return <String>[
      student.id,
      accessToken.isEmpty ? 'no_token' : 'has_token',
      ...sortedCourseOfferingIds,
      student.collegeId ?? '',
      student.departmentId ?? '',
      student.majorId ?? '',
      student.levelId ?? '',
      student.batchId ?? '',
      student.sectionId ?? '',
    ].join('|');
  }
}

class _NotificationBaseline {
  const _NotificationBaseline({
    required this.visibleNotificationIds,
    required this.readNotificationIds,
  });

  final List<String> visibleNotificationIds;
  final List<String> readNotificationIds;
}
