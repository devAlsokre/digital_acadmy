import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/student_profile.dart';

final Provider<StudentRepository> studentRepositoryProvider =
    Provider<StudentRepository>((ref) {
  return StudentRepository(ref.watch(supabaseServiceProvider));
});

class StudentRepository {
  const StudentRepository(this._supabaseService);

  static const Duration _timeout = Duration(seconds: 12);

  static const String _studentFields = '''
id,
university_number,
email,
full_name_ar,
full_name_en,
phone,
gender,
status,
college_id,
department_id,
major_id,
batch_id,
section_id,
level_id
''';

  static const String _studentFieldsWithRelations = '''
$_studentFields,
colleges(name_ar, name_en),
departments(name_ar, name_en),
majors(name_ar, name_en),
batches(name),
sections(name, code),
academic_levels(name_ar, name_en, level_number)
''';

  final SupabaseService _supabaseService;

  SupabaseClient get _client => _supabaseService.client;

  Future<StudentProfile?> getCurrentStudentProfile() async {
    final User? user = _supabaseService.currentUser;

    if (user == null) {
      return null;
    }

    try {
      final Map<String, dynamic>? student =
          await _studentWithRelations(user.id);

      if (student == null) {
        return null;
      }

      return StudentProfile.fromJson(student);
    } on PostgrestException catch (error) {
      if (!_isRelationshipError(error)) {
        throw _databaseExceptionToAppException(error);
      }

      // Relationship names can differ between Supabase schemas. If nested
      // selects are unavailable, keep the app usable with the core student row.
      return _studentWithoutRelations(user.id);
    } on TimeoutException catch (error) {
      throw AppException(
        'Cannot connect to the server. Please check your network and try again.',
        details: error,
      );
    } catch (error) {
      throw AppException(
        'Unable to load your student profile. Please try again.',
        details: error,
      );
    }
  }

  Future<Map<String, dynamic>?> _studentWithRelations(String userId) async {
    final Object? response = await _client
        .from('students')
        .select(_studentFieldsWithRelations)
        .eq('auth_user_id', userId)
        .maybeSingle()
        .timeout(_timeout);

    return _asMap(response);
  }

  Future<StudentProfile?> _studentWithoutRelations(String userId) async {
    try {
      final Object? response = await _client
          .from('students')
          .select(_studentFields)
          .eq('auth_user_id', userId)
          .maybeSingle()
          .timeout(_timeout);
      final Map<String, dynamic>? student = _asMap(response);

      if (student == null) {
        return null;
      }

      return StudentProfile.fromJson(student);
    } on PostgrestException catch (error) {
      throw _databaseExceptionToAppException(error);
    }
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

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

  AppException _databaseExceptionToAppException(PostgrestException error) {
    return AppException(
      'Unable to load your student profile. Please try again.',
      details: error,
    );
  }
}
