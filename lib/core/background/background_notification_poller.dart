import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/local_notification_service.dart';
import 'background_session_store.dart';

class BackgroundNotificationPoller {
  const BackgroundNotificationPoller({
    this.sessionStore = const BackgroundSessionStore(),
  });

  final BackgroundSessionStore sessionStore;

  Future<void> pollAndNotify(
    BackgroundStudentSession session, {
    String source = 'background_poller',
  }) async {
    if (!session.canPoll) {
      return;
    }

    final _PostgrestRestClient client = _PostgrestRestClient(session);

    try {
      final List<Map<String, dynamic>> targets =
          await client.getRows('notification_targets', <String, String>{
        'select':
            'notification_id,target_type,college_id,department_id,major_id,level_id,batch_id,section_id,student_id,course_offering_id',
        'limit': '500',
      });

      final Set<String> notificationIds = targets
          .where((target) => _matchesTarget(target, session))
          .map((target) => _asString(target['notification_id']))
          .where((id) => id.isNotEmpty)
          .toSet();

      if (kDebugMode) {
        debugPrint('Background notification targets count: ${targets.length}');
        debugPrint(
          'Background matched notifications count: ${notificationIds.length}',
        );
      }

      if (notificationIds.isEmpty) {
        _logZeroUnread(source);
        return;
      }

      final List<Map<String, dynamic>> notifications =
          await _getNotificationRows(client, notificationIds.toList());
      final Set<String> readNotificationIds =
          await _getReadNotificationIds(client, session, notificationIds);
      final Set<String> alertedIds = session.alertedNotificationIds.toSet();
      final Set<String> persistedReadIds = session.readNotificationIds.toSet();
      final List<String> mergedReadIds = _trimStoredIds(<String>[
        ...session.readNotificationIds,
        ...readNotificationIds,
      ]);
      final List<String> mergedAlertedIds = _trimStoredIds(<String>[
        ...session.alertedNotificationIds,
        ...readNotificationIds,
      ]);

      final List<Map<String, dynamic>> unreadNotifications =
          notifications.where((notification) {
        final String id = _asString(notification['id']);
        final bool alreadyRead =
            readNotificationIds.contains(id) || persistedReadIds.contains(id);
        final bool alreadyAlerted = alertedIds.contains(id);

        if (kDebugMode && id.isNotEmpty) {
          if (alreadyRead) {
            debugPrint(
              'SKIP_NOTIFICATION source=$source id=$id reason=already_read',
            );
          } else if (alreadyAlerted) {
            debugPrint(
              'SKIP_NOTIFICATION source=$source id=$id reason=already_alerted',
            );
          }
        }

        return id.isNotEmpty && !alreadyRead && !alreadyAlerted;
      }).toList();

      if (kDebugMode) {
        debugPrint(
          'Background unread notifications count: ${unreadNotifications.length}',
        );
      }

      if (unreadNotifications.isEmpty) {
        _logZeroUnread(source);
        await sessionStore.saveStudentBackgroundSession(
          session.copyWith(
            alertedNotificationIds: mergedAlertedIds,
            readNotificationIds: mergedReadIds,
          ),
        );
        return;
      }

      final List<String> updatedAlertedIds =
          List<String>.from(mergedAlertedIds);

      for (final Map<String, dynamic> notification in unreadNotifications) {
        final String id = _asString(notification['id']);
        final String title = _asString(notification['title']).isEmpty
            ? 'Digital Academy'
            : _asString(notification['title']);
        final String body = _asString(notification['body']).isEmpty
            ? 'You have a new university notification.'
            : _asString(notification['body']);
        final int unreadCount = unreadNotifications.length;

        if (id.isEmpty) {
          _logSkippedStudentAlert(source, id, 'missing_notification_id');
          continue;
        }

        if (unreadCount <= 0) {
          _logSkippedStudentAlert(source, id, 'unread_count_zero');
          continue;
        }

        if (readNotificationIds.contains(id) || persistedReadIds.contains(id)) {
          _logSkippedStudentAlert(source, id, 'already_read');
          continue;
        }

        if (alertedIds.contains(id) || updatedAlertedIds.contains(id)) {
          _logSkippedStudentAlert(source, id, 'already_alerted');
          continue;
        }

        if (kDebugMode) {
          debugPrint(
            'ABOUT_TO_SHOW_STUDENT_ALERT source=$source id=$id unreadCount=$unreadCount',
          );
        }

        await LocalNotificationService.showStudentNotification(
          id: LocalNotificationService.stableNotificationId(id),
          title: title,
          body: body,
          source: source,
          notificationKey: id,
          reason: 'new_unread',
          unreadCount: unreadCount,
        );

        updatedAlertedIds.add(id);

        if (kDebugMode) {
          debugPrint('Background local alert shown for notification: $id');
        }
      }

      await sessionStore.saveStudentBackgroundSession(
        session.copyWith(
          alertedNotificationIds: _trimStoredIds(updatedAlertedIds),
          readNotificationIds: mergedReadIds,
        ),
      );
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, dynamic>>> _getNotificationRows(
    _PostgrestRestClient client,
    List<String> notificationIds,
  ) async {
    try {
      return client.getRows('notifications', <String, String>{
        'select': 'id,title,body,type,related_table,related_id,created_at',
        'id': _inFilter(notificationIds),
        'order': 'created_at.desc',
        'limit': '100',
      });
    } on _PostgrestRestException catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }

      if (kDebugMode) {
        debugPrint(
          'Optional notification columns unavailable in background poller. Falling back to basic fields.',
        );
      }

      return client.getRows('notifications', <String, String>{
        'select': 'id,title,body,created_at',
        'id': _inFilter(notificationIds),
        'order': 'created_at.desc',
        'limit': '100',
      });
    }
  }

  Future<Set<String>> _getReadNotificationIds(
    _PostgrestRestClient client,
    BackgroundStudentSession session,
    Set<String> notificationIds,
  ) async {
    final List<Map<String, dynamic>> reads =
        await client.getRows('notification_reads', <String, String>{
      'select': 'notification_id',
      'student_id': 'eq.${session.studentId}',
      'notification_id': _inFilter(notificationIds.toList()),
    });

    return reads
        .map((read) => _asString(read['notification_id']))
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  bool _matchesTarget(
    Map<String, dynamic> target,
    BackgroundStudentSession session,
  ) {
    final String targetType = _asString(target['target_type']).toLowerCase();

    if (targetType == 'all') {
      return true;
    }

    if (targetType == 'college') {
      return _matchesNullableId(target['college_id'], session.collegeId);
    }

    if (targetType == 'department') {
      return _matchesNullableId(target['department_id'], session.departmentId);
    }

    if (targetType == 'major') {
      return _matchesNullableId(target['major_id'], session.majorId);
    }

    if (targetType == 'level') {
      return _matchesNullableId(target['level_id'], session.levelId);
    }

    if (targetType == 'batch') {
      return _matchesNullableId(target['batch_id'], session.batchId);
    }

    if (targetType == 'section') {
      return _matchesNullableId(target['section_id'], session.sectionId);
    }

    if (targetType == 'student') {
      return _matchesNullableId(target['student_id'], session.studentId);
    }

    if (targetType == 'course_offering' || targetType == 'course') {
      return session.enrolledCourseOfferingIds.contains(
        _asString(target['course_offering_id']),
      );
    }

    return _matchesNullableId(target['college_id'], session.collegeId) ||
        _matchesNullableId(target['department_id'], session.departmentId) ||
        _matchesNullableId(target['major_id'], session.majorId) ||
        _matchesNullableId(target['level_id'], session.levelId) ||
        _matchesNullableId(target['batch_id'], session.batchId) ||
        _matchesNullableId(target['section_id'], session.sectionId) ||
        _matchesNullableId(target['student_id'], session.studentId) ||
        session.enrolledCourseOfferingIds.contains(
          _asString(target['course_offering_id']),
        );
  }

  bool _matchesNullableId(Object? targetValue, String? studentValue) {
    final String target = _asString(targetValue);

    return target.isNotEmpty && studentValue != null && target == studentValue;
  }

  bool _isMissingColumnError(_PostgrestRestException error) {
    final String body = error.body.toLowerCase();
    return error.statusCode == 400 &&
        (body.contains('column') || body.contains('pgrst204'));
  }

  String _inFilter(List<String> values) {
    return 'in.(${values.join(',')})';
  }

  List<String> _trimStoredIds(List<String> ids) {
    return ids
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList()
        .reversed
        .take(BackgroundSessionStore.maxStoredNotificationIds)
        .toList()
        .reversed
        .toList();
  }

  static String _asString(Object? value) => value?.toString().trim() ?? '';

  void _logZeroUnread(String source) {
    if (!kDebugMode) {
      return;
    }

    if (source == 'workmanager') {
      debugPrint('WorkManager: unread count is 0, no notification shown.');
      debugPrint('WORKMANAGER_NO_ALERT_UNREAD_ZERO');
      return;
    }

    if (source == 'foreground_service') {
      debugPrint(
        'Foreground service: unread count is 0, no student alert shown.',
      );
      return;
    }

    debugPrint(
      'SKIP_NOTIFICATION source=$source reason=unread_count_zero',
    );
  }

  void _logSkippedStudentAlert(String source, String id, String reason) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      'SKIP_STUDENT_ALERT source=$source id=${id.isEmpty ? 'unknown' : id} reason=$reason',
    );
  }
}

class _PostgrestRestClient {
  _PostgrestRestClient(this.session);

  static const Duration _requestTimeout = Duration(seconds: 12);

  final BackgroundStudentSession session;
  final HttpClient _httpClient = HttpClient();

  Future<List<Map<String, dynamic>>> getRows(
    String table,
    Map<String, String> queryParameters,
  ) async {
    final Uri uri = _restUri(table, queryParameters);
    final HttpClientRequest request =
        await _httpClient.getUrl(uri).timeout(_requestTimeout);

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set('apikey', session.supabaseAnonKey);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${session.accessToken}',
    );

    final HttpClientResponse response =
        await request.close().timeout(_requestTimeout);
    final String body =
        await utf8.decodeStream(response).timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _PostgrestRestException(response.statusCode, body);
    }

    final Object? decoded = body.trim().isEmpty ? <Object>[] : jsonDecode(body);

    if (decoded is List) {
      return decoded
          .whereType<Object>()
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    if (decoded is Map) {
      return <Map<String, dynamic>>[Map<String, dynamic>.from(decoded)];
    }

    return <Map<String, dynamic>>[];
  }

  Uri _restUri(String table, Map<String, String> queryParameters) {
    final Uri baseUri = Uri.parse(session.supabaseUrl);
    final String basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;

    return baseUri.replace(
      path: '$basePath/rest/v1/$table',
      queryParameters: queryParameters,
    );
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

  void close() {
    _httpClient.close(force: true);
  }
}

class _PostgrestRestException implements Exception {
  const _PostgrestRestException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'PostgREST request failed: $statusCode';
}
