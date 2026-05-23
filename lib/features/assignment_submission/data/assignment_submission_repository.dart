import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../../student_dashboard/domain/student_assignment.dart';
import '../domain/selected_submission_file.dart';

final Provider<AssignmentSubmissionRepository>
    assignmentSubmissionRepositoryProvider =
    Provider<AssignmentSubmissionRepository>((ref) {
  return AssignmentSubmissionRepository(ref.watch(supabaseServiceProvider));
});

enum AssignmentSubmitResult {
  created,
  updated,
}

class AssignmentSubmissionRepository {
  const AssignmentSubmissionRepository(this._supabaseService);

  static const String _bucketName = 'submission-files';
  static const int _maxFileSizeBytes = 20 * 1024 * 1024;
  static const Duration _timeout = Duration(seconds: 20);
  static const List<String> _allowedExtensions = <String>[
    'pdf',
    'doc',
    'docx',
    'zip',
    'rar',
    'png',
    'jpg',
    'jpeg',
  ];

  final SupabaseService _supabaseService;

  SupabaseClient get _client => _supabaseService.client;

  Future<StudentAssignment?> getAssignmentDetails({
    required String assignmentId,
    required String studentId,
  }) async {
    try {
      final Map<String, dynamic>? assignment =
          await _getAssignmentWithRelations(assignmentId);

      if (assignment == null) {
        return null;
      }

      final String offeringId = _asString(assignment['course_offering_id']);
      final bool canAccess = await _studentCanAccessOffering(
        studentId: studentId,
        courseOfferingId: offeringId,
      );

      if (!canAccess) {
        return null;
      }

      final Map<String, dynamic>? submission =
          await _getExistingSubmission(assignmentId, studentId);

      return StudentAssignment.fromJson(assignment, submission: submission);
    } on PostgrestException catch (error, stackTrace) {
      _debugLogAssignmentDetailsError(
        assignmentId: assignmentId,
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );

      if (!_isRelationshipError(error)) {
        throw _detailsException(error);
      }

      return _getAssignmentDetailsFallback(
        assignmentId: assignmentId,
        studentId: studentId,
      );
    } on TimeoutException catch (error, stackTrace) {
      _debugLogAssignmentDetailsError(
        assignmentId: assignmentId,
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _networkException(error);
    } catch (error, stackTrace) {
      _debugLogAssignmentDetailsError(
        assignmentId: assignmentId,
        studentId: studentId,
        error: error,
        stackTrace: stackTrace,
      );
      throw _detailsException(error);
    }
  }

  Future<SelectedSubmissionFile?> pickSubmissionFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final PlatformFile file = result.files.single;
    final String? filePath = file.path;

    if (filePath == null || filePath.isEmpty) {
      throw const AppException(
        'Could not read the selected file. Please try another file.',
      );
    }

    if (file.size > _maxFileSizeBytes) {
      throw const AppException('File size must be less than 20 MB.');
    }

    return SelectedSubmissionFile(
      name: file.name,
      path: filePath,
      sizeBytes: file.size,
      extension: file.extension,
    );
  }

  Future<String> uploadSubmissionFile({
    required String studentId,
    required String assignmentId,
    required SelectedSubmissionFile file,
  }) async {
    final String timestamp = DateFormat('yyyyMMdd_HHmmss_SSS').format(
      DateTime.now(),
    );
    final String safeFileName = _safeFileName(file.name);
    final String storagePath =
        '$studentId/$assignmentId/${timestamp}_$safeFileName';

    try {
      await _client.storage.from(_bucketName).upload(
            storagePath,
            File(file.path),
            fileOptions: FileOptions(
              contentType: _contentTypeForExtension(file.extension),
              upsert: false,
            ),
          );

      return storagePath;
    } on TimeoutException catch (error) {
      throw _networkException(error);
    } catch (error) {
      throw AppException(
        'Could not upload file. Please check your connection and try again.',
        details: error,
      );
    }
  }

  Future<AssignmentSubmitResult> submitAssignment({
    required String assignmentId,
    required String studentId,
    required String uploadedStoragePath,
    String? answerText,
  }) async {
    Map<String, dynamic>? existingSubmission;

    try {
      existingSubmission = await _getExistingSubmission(
        assignmentId,
        studentId,
      );
      final Map<String, dynamic> payload = <String, dynamic>{
        'assignment_id': assignmentId,
        'student_id': studentId,
        'file_path': uploadedStoragePath,
        'answer_text': answerText,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'submitted',
      };

      if (existingSubmission == null) {
        await _client
            .from('assignment_submissions')
            .insert(payload)
            .timeout(_timeout);

        return AssignmentSubmitResult.created;
      } else {
        final String existingSubmissionId = _asString(existingSubmission['id']);

        await _client
            .from('assignment_submissions')
            .update(payload)
            .eq('id', existingSubmissionId)
            .timeout(_timeout);

        final String? oldFilePath = _nullableString(
          existingSubmission['file_path'],
        );

        if (oldFilePath != null && oldFilePath != uploadedStoragePath) {
          await _deleteOldSubmissionFile(oldFilePath);
        }

        return AssignmentSubmitResult.updated;
      }
    } on TimeoutException catch (error) {
      throw _networkException(error);
    } on PostgrestException catch (error, stackTrace) {
      _debugLogSubmissionSaveError(
        assignmentId: assignmentId,
        studentId: studentId,
        uploadedStoragePath: uploadedStoragePath,
        existingSubmission: existingSubmission,
        error: error,
        stackTrace: stackTrace,
      );

      throw AppException(
        'File uploaded, but submission could not be saved. Please try again.',
        details: error,
      );
    } catch (error, stackTrace) {
      _debugLogSubmissionSaveError(
        assignmentId: assignmentId,
        studentId: studentId,
        uploadedStoragePath: uploadedStoragePath,
        existingSubmission: existingSubmission,
        error: error,
        stackTrace: stackTrace,
      );

      throw AppException(
        'File uploaded, but submission could not be saved. Please try again.',
        details: error,
      );
    }
  }

  Future<void> deleteUploadedFile(String storagePath) async {
    try {
      await _client.storage.from(_bucketName).remove(<String>[storagePath]);
    } catch (_) {
      // Best-effort cleanup only. The user-facing error is handled upstream.
    }
  }

  Future<void> _deleteOldSubmissionFile(String storagePath) async {
    try {
      await _client.storage.from(_bucketName).remove(<String>[storagePath]);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Old submission file cleanup failed.');
        debugPrint('storagePath: $storagePath');
        debugPrint(error.toString());
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<Map<String, dynamic>?> _getAssignmentWithRelations(
    String assignmentId,
  ) async {
    final Object? response = await _client.from('assignments').select('''
id,
course_offering_id,
lecture_id,
title,
description,
instructions,
start_at,
due_at,
allow_late_submission,
max_grade,
status,
created_at,
lectures(lecture_number, title),
course_offerings(courses(code, name_ar, name_en))
''').eq('id', assignmentId).maybeSingle().timeout(_timeout);

    final Map<String, dynamic>? assignment = _asMap(response);

    if (assignment == null) {
      return null;
    }

    final String? attachmentUrl = await _tryGetAttachmentUrl(assignmentId);

    if (attachmentUrl != null) {
      assignment['attachment_url'] = attachmentUrl;
    }

    return assignment;
  }

  Future<StudentAssignment?> _getAssignmentDetailsFallback({
    required String assignmentId,
    required String studentId,
  }) async {
    final Object? response = await _client
        .from('assignments')
        .select(
          'id, course_offering_id, lecture_id, title, description, instructions, start_at, due_at, allow_late_submission, max_grade, status, created_at',
        )
        .eq('id', assignmentId)
        .maybeSingle()
        .timeout(_timeout);
    final Map<String, dynamic>? assignment = _asMap(response);

    if (assignment == null) {
      return null;
    }

    final String? attachmentUrl = await _tryGetAttachmentUrl(assignmentId);

    if (attachmentUrl != null) {
      assignment['attachment_url'] = attachmentUrl;
    }

    final String offeringId = _asString(assignment['course_offering_id']);
    final bool canAccess = await _studentCanAccessOffering(
      studentId: studentId,
      courseOfferingId: offeringId,
    );

    if (!canAccess) {
      return null;
    }

    final Map<String, dynamic>? offering = await _getRowById(
      'course_offerings',
      offeringId,
    );
    final Map<String, dynamic>? course = await _getRowById(
      'courses',
      _asString(offering?['course_id']),
    );
    final Map<String, dynamic>? lecture = await _getRowById(
      'lectures',
      _asString(assignment['lecture_id']),
    );
    final Map<String, dynamic>? submission =
        await _getExistingSubmission(assignmentId, studentId);

    return StudentAssignment.fromParts(
      assignment: assignment,
      course: course,
      lecture: lecture,
      submission: submission,
    );
  }

  Future<String?> _tryGetAttachmentUrl(String assignmentId) async {
    try {
      final Object? response = await _client
          .from('assignments')
          .select('attachment_url')
          .eq('id', assignmentId)
          .maybeSingle()
          .timeout(_timeout);
      final Map<String, dynamic>? row = _asMap(response);

      return _nullableString(row?['attachment_url']);
    } on PostgrestException catch (error, stackTrace) {
      if (_isMissingAttachmentColumn(error)) {
        if (kDebugMode) {
          debugPrint(
            'attachment_url column not available yet. Continuing without teacher attachment.',
          );
          debugPrint(
            'PostgrestException(message: ${error.message}, code: ${error.code}, details: ${error.details}, hint: ${error.hint})',
          );
          debugPrintStack(stackTrace: stackTrace);
        }

        return null;
      }

      rethrow;
    }
  }

  Future<bool> _studentCanAccessOffering({
    required String studentId,
    required String courseOfferingId,
  }) async {
    if (courseOfferingId.isEmpty) {
      return false;
    }

    final Object? response = await _client
        .from('course_enrollments')
        .select('id')
        .eq('student_id', studentId)
        .eq('course_offering_id', courseOfferingId)
        .eq('status', 'enrolled')
        .maybeSingle()
        .timeout(_timeout);

    return response != null;
  }

  Future<Map<String, dynamic>?> _getExistingSubmission(
    String assignmentId,
    String studentId,
  ) async {
    final Object? response = await _client
        .from('assignment_submissions')
        .select(
            'id, file_path, answer_text, submitted_at, status, grade, feedback')
        .eq('assignment_id', assignmentId)
        .eq('student_id', studentId)
        .limit(1)
        .maybeSingle()
        .timeout(_timeout);

    return _asMap(response);
  }

  Future<Map<String, dynamic>?> _getRowById(String table, String id) async {
    if (id.isEmpty) {
      return null;
    }

    final Object? response = await _client
        .from(table)
        .select()
        .eq('id', id)
        .maybeSingle()
        .timeout(_timeout);

    return _asMap(response);
  }

  String _safeFileName(String name) {
    final String normalized = name.trim().replaceAll(RegExp(r'\s+'), '_');
    final String sanitized = normalized.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '',
    );

    return sanitized.isEmpty ? 'submission_file' : sanitized;
  }

  String? _contentTypeForExtension(String? extension) {
    return switch (extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'zip' => 'application/zip',
      'rar' => 'application/vnd.rar',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is List && value.isNotEmpty) {
      return _asMap(value.first);
    }

    return null;
  }

  String _asString(Object? value) => value?.toString().trim() ?? '';

  String? _nullableString(Object? value) {
    final String stringValue = _asString(value);
    return stringValue.isEmpty ? null : stringValue;
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

  bool _isMissingAttachmentColumn(PostgrestException error) {
    final String message = error.message.toLowerCase();
    final String details = error.details?.toString().toLowerCase() ?? '';
    final String hint = error.hint?.toLowerCase() ?? '';

    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        (message.contains('attachment_url') &&
            (message.contains('column') || message.contains('schema cache'))) ||
        details.contains('attachment_url') ||
        hint.contains('attachment_url');
  }

  void _debugLogAssignmentDetailsError({
    required String assignmentId,
    required String studentId,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('Assignment details load failed.');
    debugPrint('assignmentId: $assignmentId');
    debugPrint('studentId: $studentId');

    if (error is PostgrestException) {
      debugPrint(
        'PostgrestException(message: ${error.message}, code: ${error.code}, details: ${error.details}, hint: ${error.hint})',
      );
    } else {
      debugPrint(error.toString());
    }

    debugPrintStack(stackTrace: stackTrace);
  }

  void _debugLogSubmissionSaveError({
    required String assignmentId,
    required String studentId,
    required String uploadedStoragePath,
    required Map<String, dynamic>? existingSubmission,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('Assignment submission save failed.');
    debugPrint('assignmentId: $assignmentId');
    debugPrint('studentId: $studentId');
    debugPrint('uploadedStoragePath: $uploadedStoragePath');
    debugPrint('existingSubmissionFound: ${existingSubmission != null}');
    debugPrint(
      'existingSubmissionId: ${_asString(existingSubmission?['id'])}',
    );
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

  AppException _detailsException(Object error) {
    return AppException(
      'Could not load assignment details. Please try again.',
      details: error,
    );
  }
}
