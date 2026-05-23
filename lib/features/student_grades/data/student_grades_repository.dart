import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/student_course_grades.dart';
import '../domain/student_grade_item_score.dart';

final Provider<StudentGradesRepository> studentGradesRepositoryProvider =
    Provider<StudentGradesRepository>((ref) {
  return StudentGradesRepository(ref.watch(supabaseServiceProvider));
});

class StudentGradesRepository {
  const StudentGradesRepository(this._supabaseService);

  static const Duration _timeout = Duration(seconds: 12);

  final SupabaseService _supabaseService;

  SupabaseClient get _client => _supabaseService.client;

  Future<List<StudentCourseGrades>> getMyPublishedGrades({
    required String studentId,
  }) async {
    try {
      final Object response = await _client
          .from('grade_scores')
          .select('''
id,
grade_item_id,
student_id,
score,
feedback,
is_published,
graded_at,
grade_items(
  id,
  course_offering_id,
  name,
  item_type,
  max_grade,
  weight,
  is_published,
  course_offerings(
    id,
    courses(code, name_ar, name_en),
    teachers(full_name_ar, full_name_en),
    semesters(name_ar, name_en, academic_year, term_number)
  )
)
''')
          .eq('student_id', studentId)
          .eq('is_published', true)
          .order('graded_at', ascending: false)
          .timeout(_timeout);

      final List<StudentGradeItemScore> scores = _asList(response)
          .map(StudentGradeItemScore.fromJson)
          .where(
            (score) => score.isScorePublished && score.isItemPublished,
          )
          .toList();

      return _groupByCourse(scores);
    } on PostgrestException catch (error, stackTrace) {
      _debugLogGradesError(
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );

      if (!_isRelationshipError(error)) {
        throw _gradesException(error);
      }

      return _getMyPublishedGradesFallback(studentId: studentId);
    } on TimeoutException catch (error, stackTrace) {
      _debugLogGradesError(
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _networkException(error);
    } catch (error, stackTrace) {
      _debugLogGradesError(
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _gradesException(error);
    }
  }

  Future<List<StudentCourseGrades>> _getMyPublishedGradesFallback({
    required String studentId,
  }) async {
    try {
      final Object response = await _client
          .from('grade_scores')
          .select(
            'id, grade_item_id, student_id, score, feedback, is_published, graded_at',
          )
          .eq('student_id', studentId)
          .eq('is_published', true)
          .order('graded_at', ascending: false)
          .timeout(_timeout);
      final List<Map<String, dynamic>> scoreRows = _asList(response);
      final Map<String, Map<String, dynamic>> itemRows = await _getRowsById(
        'grade_items',
        scoreRows.map((score) => _asString(score['grade_item_id'])).toList(),
      );
      final Map<String, Map<String, dynamic>> offeringRows = await _getRowsById(
        'course_offerings',
        itemRows.values
            .map((item) => _asString(item['course_offering_id']))
            .toList(),
      );
      final Map<String, Map<String, dynamic>> courseRows = await _getRowsById(
        'courses',
        offeringRows.values.map((row) => _asString(row['course_id'])).toList(),
      );
      final Map<String, Map<String, dynamic>> teacherRows = await _getRowsById(
        'teachers',
        offeringRows.values.map((row) => _asString(row['teacher_id'])).toList(),
      );
      final Map<String, Map<String, dynamic>> semesterRows = await _getRowsById(
        'semesters',
        offeringRows.values
            .map((row) => _asString(row['semester_id']))
            .toList(),
      );

      final List<StudentGradeItemScore> scores = scoreRows.map((score) {
        final Map<String, dynamic>? item =
            itemRows[_asString(score['grade_item_id'])];
        final Map<String, dynamic>? offering =
            offeringRows[_asString(item?['course_offering_id'])];

        return StudentGradeItemScore.fromParts(
          score: score,
          item: item,
          course: courseRows[_asString(offering?['course_id'])],
          teacher: teacherRows[_asString(offering?['teacher_id'])],
          semester: semesterRows[_asString(offering?['semester_id'])],
        );
      }).where((score) {
        return score.isScorePublished && score.isItemPublished;
      }).toList();

      return _groupByCourse(scores);
    } on TimeoutException catch (error, stackTrace) {
      _debugLogGradesError(
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _networkException(error);
    } catch (error, stackTrace) {
      _debugLogGradesError(
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _gradesException(error);
    }
  }

  List<StudentCourseGrades> _groupByCourse(
    List<StudentGradeItemScore> scores,
  ) {
    final Map<String, List<StudentGradeItemScore>> grouped =
        <String, List<StudentGradeItemScore>>{};

    for (final StudentGradeItemScore score in scores) {
      if (score.courseOfferingId.isEmpty) {
        continue;
      }

      grouped.putIfAbsent(score.courseOfferingId, () {
        return <StudentGradeItemScore>[];
      }).add(score);
    }

    final List<StudentCourseGrades> courseGrades = grouped.values
        .where((items) => items.isNotEmpty)
        .map(StudentCourseGrades.fromItems)
        .toList();

    courseGrades.sort((a, b) {
      return a.displayCourseName.compareTo(b.displayCourseName);
    });

    return courseGrades;
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

  void _debugLogGradesError({
    required String studentId,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('Student grades fetch failed.');
    debugPrint('studentId: $studentId');
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

  AppException _gradesException(Object error) {
    return AppException(
      'Could not load grades. Please try again.',
      details: error,
    );
  }
}
