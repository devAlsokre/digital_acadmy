import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../../student_profile/domain/student_profile.dart';
import '../domain/student_notification.dart';

final Provider<StudentNotificationsRepository>
    studentNotificationsRepositoryProvider =
    Provider<StudentNotificationsRepository>((ref) {
  return StudentNotificationsRepository(ref.watch(supabaseServiceProvider));
});

class StudentNotificationsRepository {
  const StudentNotificationsRepository(this._supabaseService);

  static const Duration _timeout = Duration(seconds: 12);

  final SupabaseService _supabaseService;

  SupabaseClient get _client => _supabaseService.client;

  Future<StudentNotification?> getNotificationById({
    required String notificationId,
    required String studentId,
  }) async {
    try {
      final List<Map<String, dynamic>> rows =
          await _getNotificationRows(<String>[notificationId]);

      if (rows.isEmpty) {
        return null;
      }

      final bool isRead = await isNotificationRead(
        notificationId: notificationId,
        studentId: studentId,
      );

      return StudentNotification.fromJson(
        rows.first,
        readAt: isRead ? DateTime.now() : null,
      );
    } on TimeoutException catch (error, stackTrace) {
      _debugLogNotificationError(
        studentId: studentId,
        notificationId: notificationId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _networkException(error);
    } catch (error, stackTrace) {
      _debugLogNotificationError(
        studentId: studentId,
        notificationId: notificationId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _notificationsException(error);
    }
  }

  Future<bool> isNotificationRead({
    required String notificationId,
    required String studentId,
  }) async {
    final Object? existing = await _client
        .from('notification_reads')
        .select('notification_id')
        .eq('notification_id', notificationId)
        .eq('student_id', studentId)
        .maybeSingle()
        .timeout(_timeout);

    return existing != null;
  }

  Future<List<StudentNotification>> getMyNotifications({
    required StudentProfile student,
    required List<String> courseOfferingIds,
  }) async {
    try {
      final Object targetsResponse =
          await _client.from('notification_targets').select('''
notification_id,
target_type,
college_id,
department_id,
major_id,
level_id,
batch_id,
section_id,
student_id,
course_offering_id
''').limit(500).timeout(_timeout);

      final Set<String> notificationIds = _asList(targetsResponse)
          .where(
            (target) => _matchesTarget(
              target,
              student,
              courseOfferingIds,
            ),
          )
          .map((target) => _asString(target['notification_id']))
          .where((id) => id.isNotEmpty)
          .toSet();

      if (notificationIds.isEmpty) {
        return <StudentNotification>[];
      }

      final List<Map<String, dynamic>> notificationRows =
          await _getNotificationRows(notificationIds.toList());

      final Map<String, DateTime> readsByNotificationId =
          await _getReadsByNotificationId(
        studentId: student.id,
        notificationIds: notificationIds.toList(),
      );

      final List<StudentNotification> notifications = notificationRows
          .map(
            (notification) => StudentNotification.fromJson(
              notification,
              readAt: readsByNotificationId[_asString(notification['id'])],
            ),
          )
          .where((notification) => notification.id.isNotEmpty)
          .toList();

      notifications.sort((a, b) {
        final DateTime aDate =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return notifications;
    } on TimeoutException catch (error, stackTrace) {
      _debugLogNotificationError(
        studentId: student.id,
        error: error,
        stackTrace: stackTrace,
      );
      throw _networkException(error);
    } catch (error, stackTrace) {
      _debugLogNotificationError(
        studentId: student.id,
        error: error,
        stackTrace: stackTrace,
      );
      throw _notificationsException(error);
    }
  }

  Future<void> markAsRead({
    required String notificationId,
    required String studentId,
  }) async {
    try {
      final Object? existing = await _client
          .from('notification_reads')
          .select('notification_id')
          .eq('notification_id', notificationId)
          .eq('student_id', studentId)
          .maybeSingle()
          .timeout(_timeout);

      if (existing != null) {
        return;
      }

      await _client.from('notification_reads').insert(<String, dynamic>{
        'notification_id': notificationId,
        'student_id': studentId,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(_timeout);
    } on PostgrestException catch (error, stackTrace) {
      _debugLogNotificationError(
        studentId: studentId,
        notificationId: notificationId,
        error: error,
        stackTrace: stackTrace,
      );

      if (_isDuplicateError(error)) {
        return;
      }

      throw _markReadException(error);
    } on TimeoutException catch (error, stackTrace) {
      _debugLogNotificationError(
        studentId: studentId,
        notificationId: notificationId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _networkException(error);
    } catch (error, stackTrace) {
      _debugLogNotificationError(
        studentId: studentId,
        notificationId: notificationId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _markReadException(error);
    }
  }

  Future<void> markAllAsRead({
    required List<String> notificationIds,
    required String studentId,
  }) async {
    final List<String> cleanIds =
        notificationIds.where((id) => id.trim().isNotEmpty).toSet().toList();

    if (cleanIds.isEmpty) {
      return;
    }

    try {
      final Map<String, DateTime> existingReads =
          await _getReadsByNotificationId(
        studentId: studentId,
        notificationIds: cleanIds,
      );
      final List<String> unreadIds =
          cleanIds.where((id) => !existingReads.containsKey(id)).toList();

      if (unreadIds.isEmpty) {
        return;
      }

      final String readAt = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('notification_reads')
          .insert(
            unreadIds.map((id) {
              return <String, dynamic>{
                'notification_id': id,
                'student_id': studentId,
                'read_at': readAt,
              };
            }).toList(),
          )
          .timeout(_timeout);
    } on PostgrestException catch (error, stackTrace) {
      _debugLogNotificationError(
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );

      if (_isDuplicateError(error)) {
        return;
      }

      throw _markReadException(error);
    } on TimeoutException catch (error, stackTrace) {
      _debugLogNotificationError(
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _networkException(error);
    } catch (error, stackTrace) {
      _debugLogNotificationError(
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _markReadException(error);
    }
  }

  Future<Map<String, DateTime>> _getReadsByNotificationId({
    required String studentId,
    required List<String> notificationIds,
  }) async {
    final List<String> cleanIds =
        notificationIds.where((id) => id.trim().isNotEmpty).toSet().toList();

    if (cleanIds.isEmpty) {
      return <String, DateTime>{};
    }

    final Object response = await _client
        .from('notification_reads')
        .select('notification_id, read_at')
        .eq('student_id', studentId)
        .inFilter('notification_id', cleanIds)
        .timeout(_timeout);

    return <String, DateTime>{
      for (final Map<String, dynamic> row in _asList(response))
        if (_asString(row['notification_id']).isNotEmpty &&
            _asDateTime(row['read_at']) != null)
          _asString(row['notification_id']): _asDateTime(row['read_at'])!,
    };
  }

  Future<List<Map<String, dynamic>>> _getNotificationRows(
    List<String> notificationIds,
  ) async {
    try {
      final Object response = await _client
          .from('notifications')
          .select(
              'id, title, body, type, related_table, related_id, created_at')
          .inFilter('id', notificationIds)
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(_timeout);

      return _asList(response);
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }

      if (kDebugMode) {
        debugPrint(
          'Optional notification columns are not available. Continuing with basic notification fields.',
        );
      }

      final Object response = await _client
          .from('notifications')
          .select('id, title, body, created_at')
          .inFilter('id', notificationIds)
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(_timeout);

      return _asList(response);
    }
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

    if (targetType == 'course_offering' || targetType == 'course') {
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

  bool _isDuplicateError(PostgrestException error) {
    return error.code == '23505' ||
        error.message.toLowerCase().contains('duplicate');
  }

  bool _isMissingColumnError(PostgrestException error) {
    final String message = error.message.toLowerCase();
    final String details = error.details?.toString().toLowerCase() ?? '';

    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        message.contains('column') ||
        details.contains('column');
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is List) {
      return value
          .whereType<Object>()
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String _asString(Object? value) => value?.toString().trim() ?? '';

  DateTime? _asDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  void _debugLogNotificationError({
    required String studentId,
    String? notificationId,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('Student notifications operation failed.');
    debugPrint('studentId: $studentId');
    if (notificationId != null) {
      debugPrint('notificationId: $notificationId');
    }
    debugPrint('exceptionType: ${error.runtimeType}');

    if (error is PostgrestException) {
      debugPrint(
        'PostgrestException(message: ${error.message}, code: ${error.code}, details: ${error.details}, hint: ${error.hint})',
      );
    } else {
      debugPrint(error.toString());
    }

    debugPrintStack(stackTrace: stackTrace);
  }

  AppException _networkException(Object error) {
    return AppException(
      'Cannot connect to the server. Please check your network and try again.',
      details: error,
    );
  }

  AppException _notificationsException(Object error) {
    return AppException(
      'Could not load notifications. Please try again.',
      details: error,
    );
  }

  AppException _markReadException(Object error) {
    return AppException(
      'Could not mark notification as read.',
      details: error,
    );
  }
}
