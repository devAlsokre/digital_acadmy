import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundStudentSession {
  const BackgroundStudentSession({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.accessToken,
    required this.studentId,
    required this.collegeId,
    required this.departmentId,
    required this.majorId,
    required this.levelId,
    required this.batchId,
    required this.sectionId,
    required this.enrolledCourseOfferingIds,
    required this.alertedNotificationIds,
    required this.readNotificationIds,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String accessToken;
  final String studentId;
  final String? collegeId;
  final String? departmentId;
  final String? majorId;
  final String? levelId;
  final String? batchId;
  final String? sectionId;
  final List<String> enrolledCourseOfferingIds;
  final List<String> alertedNotificationIds;
  final List<String> readNotificationIds;

  bool get canPoll {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        accessToken.isNotEmpty &&
        studentId.isNotEmpty;
  }

  BackgroundStudentSession copyWith({
    List<String>? alertedNotificationIds,
    List<String>? readNotificationIds,
  }) {
    return BackgroundStudentSession(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      accessToken: accessToken,
      studentId: studentId,
      collegeId: collegeId,
      departmentId: departmentId,
      majorId: majorId,
      levelId: levelId,
      batchId: batchId,
      sectionId: sectionId,
      enrolledCourseOfferingIds: enrolledCourseOfferingIds,
      alertedNotificationIds:
          alertedNotificationIds ?? this.alertedNotificationIds,
      readNotificationIds: readNotificationIds ?? this.readNotificationIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
      'accessToken': accessToken,
      'studentId': studentId,
      'collegeId': collegeId,
      'departmentId': departmentId,
      'majorId': majorId,
      'levelId': levelId,
      'batchId': batchId,
      'sectionId': sectionId,
      'enrolledCourseOfferingIds': enrolledCourseOfferingIds,
      'alertedNotificationIds': alertedNotificationIds,
      'readNotificationIds': readNotificationIds,
    };
  }

  factory BackgroundStudentSession.fromJson(Map<String, dynamic> json) {
    return BackgroundStudentSession(
      supabaseUrl: _asString(json['supabaseUrl']),
      supabaseAnonKey: _asString(json['supabaseAnonKey']),
      accessToken: _asString(json['accessToken']),
      studentId: _asString(json['studentId']),
      collegeId: _nullableString(json['collegeId']),
      departmentId: _nullableString(json['departmentId']),
      majorId: _nullableString(json['majorId']),
      levelId: _nullableString(json['levelId']),
      batchId: _nullableString(json['batchId']),
      sectionId: _nullableString(json['sectionId']),
      enrolledCourseOfferingIds: _stringList(json['enrolledCourseOfferingIds']),
      alertedNotificationIds: _stringList(json['alertedNotificationIds']),
      readNotificationIds: _stringList(json['readNotificationIds']),
    );
  }

  static String _asString(Object? value) => value?.toString().trim() ?? '';

  static String? _nullableString(Object? value) {
    final String stringValue = _asString(value);
    return stringValue.isEmpty ? null : stringValue;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
}

class BackgroundSessionStore {
  const BackgroundSessionStore();

  static const String _sessionKey = 'digital_academy_background_session';
  static const int maxStoredNotificationIds = 300;

  Future<void> saveStudentBackgroundSession(
    BackgroundStudentSession session,
  ) async {
    // TODO: Use secure storage for access tokens in a future hardening phase.
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));

    if (kDebugMode) {
      debugPrint('Background notification session saved.');
    }
  }

  Future<BackgroundStudentSession?> loadStudentBackgroundSession() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? rawSession = preferences.getString(_sessionKey);

    if (rawSession == null || rawSession.trim().isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(rawSession);
      if (decoded is Map<String, dynamic>) {
        return BackgroundStudentSession.fromJson(decoded);
      }

      if (decoded is Map) {
        return BackgroundStudentSession.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not decode background notification session: $error');
      }
    }

    return null;
  }

  Future<void> clearStudentBackgroundSession() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);

    if (kDebugMode) {
      debugPrint('Background notification session cleared.');
    }
  }

  Future<void> addAlertedNotificationId(String notificationId) async {
    await _updateStoredIds(
      notificationId: notificationId,
      addToAlerted: true,
      addToRead: false,
    );
  }

  Future<void> addReadNotificationId(String notificationId) async {
    await _updateStoredIds(
      notificationId: notificationId,
      addToAlerted: true,
      addToRead: true,
    );
  }

  Future<void> _updateStoredIds({
    required String notificationId,
    required bool addToAlerted,
    required bool addToRead,
  }) async {
    final String cleanId = notificationId.trim();

    if (cleanId.isEmpty) {
      return;
    }

    final BackgroundStudentSession? session =
        await loadStudentBackgroundSession();

    if (session == null) {
      return;
    }

    await saveStudentBackgroundSession(
      session.copyWith(
        alertedNotificationIds: addToAlerted
            ? _trimStoredIds(<String>[
                ...session.alertedNotificationIds,
                cleanId,
              ])
            : null,
        readNotificationIds: addToRead
            ? _trimStoredIds(<String>[
                ...session.readNotificationIds,
                cleanId,
              ])
            : null,
      ),
    );
  }

  List<String> _trimStoredIds(List<String> ids) {
    return ids
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList()
        .reversed
        .take(maxStoredNotificationIds)
        .toList()
        .reversed
        .toList();
  }
}
