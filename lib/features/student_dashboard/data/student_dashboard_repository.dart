import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../../student_profile/domain/student_profile.dart';
import '../domain/student_announcement.dart';
import '../domain/student_assignment.dart';
import '../domain/student_course.dart';
import '../domain/student_dashboard_data.dart';
import '../domain/student_schedule_item.dart';

final Provider<StudentDashboardRepository> studentDashboardRepositoryProvider =
    Provider<StudentDashboardRepository>((ref) {
  return StudentDashboardRepository(ref.watch(supabaseServiceProvider));
});

class StudentDashboardRepository {
  const StudentDashboardRepository(this._supabaseService);

  static const Duration _timeout = Duration(seconds: 12);

  final SupabaseService _supabaseService;

  SupabaseClient get _client => _supabaseService.client;

  Future<StudentDashboardData> getDashboardData(StudentProfile student) async {
    final List<StudentCourse> courses = await getMyCourses(student.id);
    final List<String> offeringIds = courses
        .map((course) => course.courseOfferingId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final List<StudentScheduleItem> scheduleItems =
        await getMySchedule(offeringIds);
    final List<StudentAssignment> assignments =
        await getMyAssignments(student.id, offeringIds);
    final List<StudentAnnouncement> announcements =
        await getMyAnnouncements(student, courseOfferingIds: offeringIds);

    return StudentDashboardData(
      courses: courses,
      scheduleItems: scheduleItems,
      openAssignments: assignments,
      announcements: announcements,
    );
  }

  Future<List<StudentCourse>> getMyCourses(String studentId) async {
    try {
      final Object response =
          await _client.from('course_enrollments').select('''
id,
student_id,
course_offering_id,
status,
course_offerings(
  id,
  courses(code, name_ar, name_en),
  teachers(full_name_ar, full_name_en),
  semesters(name_ar, name_en, academic_year, term_number)
)
''').eq('student_id', studentId).eq('status', 'enrolled').timeout(_timeout);

      return _asList(response)
          .map(StudentCourse.fromEnrollmentJson)
          .where((course) => course.courseOfferingId.isNotEmpty)
          .toList();
    } on PostgrestException catch (error) {
      if (!_isRelationshipError(error)) {
        throw _dashboardException(error);
      }

      return _getMyCoursesFallback(studentId);
    } on TimeoutException catch (error) {
      throw _networkException(error);
    } catch (error) {
      throw _dashboardException(error);
    }
  }

  Future<List<StudentScheduleItem>> getMySchedule(
    List<String> courseOfferingIds,
  ) async {
    if (courseOfferingIds.isEmpty) {
      return <StudentScheduleItem>[];
    }

    try {
      final Object response = await _client
          .from('class_schedules')
          .select('''
id,
course_offering_id,
day_of_week,
start_time,
end_time,
room,
location,
schedule_type,
course_offerings(courses(code, name_ar, name_en))
''')
          .inFilter('course_offering_id', courseOfferingIds)
          .order('day_of_week', ascending: true)
          .order('start_time', ascending: true)
          .timeout(_timeout);

      return _asList(response).map(StudentScheduleItem.fromJson).toList();
    } on PostgrestException catch (error) {
      if (!_isRelationshipError(error)) {
        throw _dashboardException(error);
      }

      return _getMyScheduleFallback(courseOfferingIds);
    } on TimeoutException catch (error) {
      throw _networkException(error);
    } catch (error) {
      throw _dashboardException(error);
    }
  }

  Future<List<StudentAssignment>> getMyAssignments(
    String studentId,
    List<String> courseOfferingIds,
  ) async {
    if (courseOfferingIds.isEmpty) {
      return <StudentAssignment>[];
    }

    try {
      final Object response = await _client
          .from('assignments')
          .select('''
id,
course_offering_id,
lecture_id,
title,
description,
instructions,
start_at,
due_at,
max_grade,
status,
lectures(lecture_number, title),
course_offerings(courses(code, name_ar, name_en))
''')
          .inFilter('course_offering_id', courseOfferingIds)
          .eq('status', 'published')
          .order('due_at', ascending: true)
          .timeout(_timeout);

      final List<Map<String, dynamic>> assignmentRows = _asList(response);
      final Map<String, Map<String, dynamic>> submissions =
          await _getSubmissionsByAssignmentId(studentId, assignmentRows);

      return assignmentRows
          .map(
            (assignment) => StudentAssignment.fromJson(
              assignment,
              submission: submissions[_asString(assignment['id'])],
            ),
          )
          .toList();
    } on PostgrestException catch (error) {
      if (!_isRelationshipError(error)) {
        throw _dashboardException(error);
      }

      return _getMyAssignmentsFallback(studentId, courseOfferingIds);
    } on TimeoutException catch (error) {
      throw _networkException(error);
    } catch (error) {
      throw _dashboardException(error);
    }
  }

  Future<List<StudentAnnouncement>> getMyAnnouncements(
    StudentProfile student, {
    List<String> courseOfferingIds = const <String>[],
  }) async {
    try {
      final Object targetsResponse =
          await _client.from('announcement_targets').select('''
announcement_id,
target_type,
college_id,
department_id,
major_id,
level_id,
batch_id,
section_id,
student_id,
course_offering_id
''').limit(300).timeout(_timeout);

      final Set<String> announcementIds = _asList(targetsResponse)
          .where((target) => _matchesAnnouncementTarget(
                target,
                student,
                courseOfferingIds,
              ))
          .map((target) => _asString(target['announcement_id']))
          .where((id) => id.isNotEmpty)
          .toSet();

      if (announcementIds.isEmpty) {
        return <StudentAnnouncement>[];
      }

      final Object response = await _client
          .from('announcements')
          .select(
              'id, title, body, priority, publish_at, expires_at, created_at')
          .inFilter('id', announcementIds.toList())
          .order('created_at', ascending: false)
          .limit(50)
          .timeout(_timeout);

      final List<StudentAnnouncement> announcements = _asList(response)
          .map(StudentAnnouncement.fromJson)
          .where((announcement) => announcement.isActive)
          .toList();

      announcements.sort((a, b) {
        final DateTime aDate = a.publishAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate = b.publishAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return announcements;
    } on TimeoutException catch (error) {
      throw _networkException(error);
    } on PostgrestException {
      return <StudentAnnouncement>[];
    } catch (_) {
      return <StudentAnnouncement>[];
    }
  }

  Future<List<StudentCourse>> _getMyCoursesFallback(String studentId) async {
    final Object enrollmentsResponse = await _client
        .from('course_enrollments')
        .select('id, student_id, course_offering_id, status')
        .eq('student_id', studentId)
        .eq('status', 'enrolled')
        .timeout(_timeout);
    final List<Map<String, dynamic>> enrollments = _asList(enrollmentsResponse);
    final List<String> offeringIds = enrollments
        .map((row) => _asString(row['course_offering_id']))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> offerings =
        await _getRowsById('course_offerings', offeringIds);
    final Map<String, Map<String, dynamic>> courses = await _getRowsById(
      'courses',
      offerings.values.map((row) => _asString(row['course_id'])).toList(),
    );
    final Map<String, Map<String, dynamic>> teachers = await _getRowsById(
      'teachers',
      offerings.values.map((row) => _asString(row['teacher_id'])).toList(),
    );
    final Map<String, Map<String, dynamic>> semesters = await _getRowsById(
      'semesters',
      offerings.values.map((row) => _asString(row['semester_id'])).toList(),
    );

    return enrollments.map((enrollment) {
      final Map<String, dynamic>? offering =
          offerings[_asString(enrollment['course_offering_id'])];

      return StudentCourse.fromParts(
        enrollment: enrollment,
        offering: offering,
        course: courses[_asString(offering?['course_id'])],
        teacher: teachers[_asString(offering?['teacher_id'])],
        semester: semesters[_asString(offering?['semester_id'])],
      );
    }).toList();
  }

  Future<List<StudentScheduleItem>> _getMyScheduleFallback(
    List<String> courseOfferingIds,
  ) async {
    final Object response = await _client
        .from('class_schedules')
        .select(
          'id, course_offering_id, day_of_week, start_time, end_time, room, location, schedule_type',
        )
        .inFilter('course_offering_id', courseOfferingIds)
        .order('day_of_week', ascending: true)
        .order('start_time', ascending: true)
        .timeout(_timeout);
    final List<Map<String, dynamic>> schedules = _asList(response);
    final Map<String, Map<String, dynamic>> courseByOfferingId =
        await _getCourseByOfferingId(courseOfferingIds);

    return schedules
        .map(
          (schedule) => StudentScheduleItem.fromParts(
            schedule: schedule,
            course:
                courseByOfferingId[_asString(schedule['course_offering_id'])],
          ),
        )
        .toList();
  }

  Future<List<StudentAssignment>> _getMyAssignmentsFallback(
    String studentId,
    List<String> courseOfferingIds,
  ) async {
    final Object response = await _client
        .from('assignments')
        .select(
          'id, course_offering_id, lecture_id, title, description, instructions, start_at, due_at, max_grade, status',
        )
        .inFilter('course_offering_id', courseOfferingIds)
        .eq('status', 'published')
        .order('due_at', ascending: true)
        .timeout(_timeout);
    final List<Map<String, dynamic>> assignments = _asList(response);
    final Map<String, Map<String, dynamic>> submissions =
        await _getSubmissionsByAssignmentId(studentId, assignments);
    final Map<String, Map<String, dynamic>> lectures = await _getRowsById(
      'lectures',
      assignments.map((row) => _asString(row['lecture_id'])).toList(),
    );
    final Map<String, Map<String, dynamic>> courseByOfferingId =
        await _getCourseByOfferingId(courseOfferingIds);

    return assignments.map((assignment) {
      return StudentAssignment.fromParts(
        assignment: assignment,
        course: courseByOfferingId[_asString(assignment['course_offering_id'])],
        lecture: lectures[_asString(assignment['lecture_id'])],
        submission: submissions[_asString(assignment['id'])],
      );
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _getSubmissionsByAssignmentId(
    String studentId,
    List<Map<String, dynamic>> assignmentRows,
  ) async {
    final List<String> assignmentIds = assignmentRows
        .map((assignment) => _asString(assignment['id']))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (assignmentIds.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    final Object response = await _client
        .from('assignment_submissions')
        .select('id, assignment_id, status, submitted_at')
        .eq('student_id', studentId)
        .inFilter('assignment_id', assignmentIds)
        .timeout(_timeout);

    return <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> row in _asList(response))
        if (_asString(row['assignment_id']).isNotEmpty)
          _asString(row['assignment_id']): row,
    };
  }

  Future<Map<String, Map<String, dynamic>>> _getCourseByOfferingId(
    List<String> courseOfferingIds,
  ) async {
    final Map<String, Map<String, dynamic>> offerings =
        await _getRowsById('course_offerings', courseOfferingIds);
    final Map<String, Map<String, dynamic>> courses = await _getRowsById(
      'courses',
      offerings.values.map((row) => _asString(row['course_id'])).toList(),
    );

    return <String, Map<String, dynamic>>{
      for (final MapEntry<String, Map<String, dynamic>> entry
          in offerings.entries)
        entry.key:
            courses[_asString(entry.value['course_id'])] ?? <String, dynamic>{},
    };
  }

  Future<Map<String, Map<String, dynamic>>> _getRowsById(
    String table,
    List<String> ids,
  ) async {
    final List<String> cleanIds =
        ids.where((id) => id.trim().isNotEmpty).toSet().toList();

    if (cleanIds.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    final Object response = await _client
        .from(table)
        .select()
        .inFilter('id', cleanIds)
        .timeout(_timeout);

    return <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> row in _asList(response))
        if (_asString(row['id']).isNotEmpty) _asString(row['id']): row,
    };
  }

  bool _matchesAnnouncementTarget(
    Map<String, dynamic> target,
    StudentProfile student,
    List<String> courseOfferingIds,
  ) {
    final String targetType = _asString(target['target_type']).toLowerCase();

    if (targetType == 'all') {
      return true;
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

  bool _isRelationshipError(PostgrestException error) {
    final String message = error.message.toLowerCase();
    final String details = error.details?.toString().toLowerCase() ?? '';
    final String hint = error.hint?.toLowerCase() ?? '';

    return error.code == 'PGRST200' ||
        message.contains('relationship') ||
        details.contains('relationship') ||
        hint.contains('relationship') ||
        message.contains('could not find');
  }

  AppException _networkException(Object error) {
    return AppException(
      'Cannot connect to the server. Please check your network and try again.',
      details: error,
    );
  }

  AppException _dashboardException(Object error) {
    return AppException(
      'Could not load dashboard data. Please try again.',
      details: error,
    );
  }
}
