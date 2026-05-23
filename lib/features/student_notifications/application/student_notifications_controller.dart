import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_notification_service.dart';
import '../../student_dashboard/application/student_dashboard_controller.dart';
import '../../student_dashboard/data/student_dashboard_repository.dart';
import '../../student_dashboard/domain/student_course.dart';
import '../../student_dashboard/domain/student_dashboard_data.dart';
import '../../student_profile/application/student_profile_controller.dart';
import '../../student_profile/domain/student_profile.dart';
import '../data/student_notifications_repository.dart';
import '../domain/student_notification.dart';
import 'notification_alert_dedup_service.dart';

final StateNotifierProvider<StudentNotificationsController,
        AsyncValue<List<StudentNotification>>>
    studentNotificationsControllerProvider = StateNotifierProvider<
        StudentNotificationsController,
        AsyncValue<List<StudentNotification>>>((ref) {
  return StudentNotificationsController(
    ref.watch(studentNotificationsRepositoryProvider),
    ref.watch(studentDashboardRepositoryProvider),
    ref.watch(notificationAlertDedupServiceProvider),
    ref,
  );
});

class StudentNotificationsController
    extends StateNotifier<AsyncValue<List<StudentNotification>>> {
  StudentNotificationsController(
    this._repository,
    this._dashboardRepository,
    this._dedupService,
    this._ref,
  ) : super(const AsyncValue.data(<StudentNotification>[]));

  final StudentNotificationsRepository _repository;
  final StudentDashboardRepository _dashboardRepository;
  final NotificationAlertDedupService _dedupService;
  final Ref _ref;

  int get unreadCount {
    return state.valueOrNull
            ?.where((notification) => !notification.isRead)
            .length ??
        0;
  }

  Future<List<StudentNotification>> loadNotifications({
    bool force = false,
  }) async {
    final List<StudentNotification>? currentNotifications = state.valueOrNull;

    if (!force &&
        currentNotifications != null &&
        currentNotifications.isNotEmpty) {
      return currentNotifications;
    }

    state = const AsyncValue.loading();

    try {
      final StudentProfile? student =
          _ref.read(studentProfileControllerProvider).valueOrNull ??
              await _ref
                  .read(studentProfileControllerProvider.notifier)
                  .loadCurrentStudentProfile(force: force);

      if (student == null) {
        state = const AsyncValue.data(<StudentNotification>[]);
        return <StudentNotification>[];
      }

      final List<String> courseOfferingIds =
          await _getCourseOfferingIds(student);
      final List<StudentNotification> notifications =
          await _repository.getMyNotifications(
        student: student,
        courseOfferingIds: courseOfferingIds,
      );

      state = AsyncValue.data(notifications);
      return notifications;
    } on AppException catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      final AppException exception = AppException(
        'Could not load notifications. Please try again.',
        details: error,
      );
      state = AsyncValue.error(exception, stackTrace);
      throw exception;
    }
  }

  Future<void> refresh() async {
    await loadNotifications(force: true);
  }

  Future<void> markAsRead(String notificationId) async {
    final StudentProfile? student =
        _ref.read(studentProfileControllerProvider).valueOrNull ??
            await _ref
                .read(studentProfileControllerProvider.notifier)
                .loadCurrentStudentProfile();

    if (student == null) {
      throw const AppException(
        'Your student profile could not be loaded. Please try again.',
      );
    }

    await _repository.markAsRead(
      notificationId: notificationId,
      studentId: student.id,
    );
    await _dedupService.markRead(notificationId);
    await LocalNotificationService.cancelStudentNotification(notificationId);

    markLocalAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    final StudentProfile? student =
        _ref.read(studentProfileControllerProvider).valueOrNull ??
            await _ref
                .read(studentProfileControllerProvider.notifier)
                .loadCurrentStudentProfile();
    final List<StudentNotification> notifications =
        state.valueOrNull ?? const <StudentNotification>[];
    final List<String> unreadIds = notifications
        .where((notification) => !notification.isRead)
        .map((notification) => notification.id)
        .where((id) => id.isNotEmpty)
        .toList();

    if (student == null || unreadIds.isEmpty) {
      return;
    }

    await _repository.markAllAsRead(
      notificationIds: unreadIds,
      studentId: student.id,
    );

    for (final String notificationId in unreadIds) {
      await _dedupService.markRead(notificationId);
      await LocalNotificationService.cancelStudentNotification(notificationId);
    }

    markAllLocalAsRead(unreadIds);
  }

  void addOrUpdateNotification(StudentNotification notification) {
    if (notification.id.isEmpty) {
      return;
    }

    final List<StudentNotification> notifications =
        state.valueOrNull ?? const <StudentNotification>[];
    final int existingIndex = notifications.indexWhere(
      (current) => current.id == notification.id,
    );

    final List<StudentNotification> updated =
        List<StudentNotification>.from(notifications);

    if (existingIndex >= 0) {
      updated[existingIndex] = notification;
    } else {
      updated.insert(0, notification);
    }

    updated.sort((a, b) {
      final DateTime aDate =
          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate =
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    state = AsyncValue.data(updated);
  }

  void markLocalAsRead(String notificationId, {DateTime? readAt}) {
    final List<StudentNotification>? notifications = state.valueOrNull;

    if (notifications == null) {
      return;
    }

    final DateTime resolvedReadAt = readAt ?? DateTime.now();
    state = AsyncValue.data(
      notifications.map((notification) {
        if (notification.id != notificationId || notification.isRead) {
          return notification;
        }

        return notification.copyWith(readAt: resolvedReadAt);
      }).toList(),
    );
  }

  void markAllLocalAsRead(List<String> notificationIds) {
    final Set<String> ids = notificationIds.toSet();
    final List<StudentNotification>? notifications = state.valueOrNull;

    if (notifications == null || ids.isEmpty) {
      return;
    }

    final DateTime readAt = DateTime.now();
    state = AsyncValue.data(
      notifications.map((notification) {
        if (notification.isRead || !ids.contains(notification.id)) {
          return notification;
        }

        return notification.copyWith(readAt: readAt);
      }).toList(),
    );
  }

  Future<List<String>> _getCourseOfferingIds(StudentProfile student) async {
    final StudentDashboardData? dashboardData =
        _ref.read(studentDashboardControllerProvider).valueOrNull;
    final List<String> existingIds = dashboardData?.courses
            .map((course) => course.courseOfferingId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList() ??
        <String>[];

    if (existingIds.isNotEmpty) {
      return existingIds;
    }

    final List<StudentCourse> courses =
        await _dashboardRepository.getMyCourses(student.id);

    return courses
        .map((course) => course.courseOfferingId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }
}
