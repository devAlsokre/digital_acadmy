import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../student_dashboard/domain/student_assignment.dart';
import '../data/assignment_submission_repository.dart';
import '../domain/selected_submission_file.dart';

final StateNotifierProvider<AssignmentSubmissionController,
        AssignmentSubmissionState> assignmentSubmissionControllerProvider =
    StateNotifierProvider<AssignmentSubmissionController,
        AssignmentSubmissionState>((ref) {
  return AssignmentSubmissionController(
    ref.watch(assignmentSubmissionRepositoryProvider),
  );
});

enum AssignmentSubmissionStatus {
  idle,
  pickingFile,
  fileSelected,
  uploading,
  submitted,
  error,
}

class AssignmentSubmissionState {
  const AssignmentSubmissionState({
    this.status = AssignmentSubmissionStatus.idle,
    this.assignment,
    this.selectedFile,
    this.message,
    this.debugMessage,
  });

  final AssignmentSubmissionStatus status;
  final StudentAssignment? assignment;
  final SelectedSubmissionFile? selectedFile;
  final String? message;
  final String? debugMessage;

  bool get isBusy =>
      status == AssignmentSubmissionStatus.pickingFile ||
      status == AssignmentSubmissionStatus.uploading;

  AssignmentSubmissionState copyWith({
    AssignmentSubmissionStatus? status,
    StudentAssignment? assignment,
    SelectedSubmissionFile? selectedFile,
    String? message,
    String? debugMessage,
    bool clearSelectedFile = false,
    bool clearMessage = false,
    bool clearDebugMessage = false,
  }) {
    return AssignmentSubmissionState(
      status: status ?? this.status,
      assignment: assignment ?? this.assignment,
      selectedFile:
          clearSelectedFile ? null : selectedFile ?? this.selectedFile,
      message: clearMessage ? null : message ?? this.message,
      debugMessage:
          clearDebugMessage ? null : debugMessage ?? this.debugMessage,
    );
  }
}

class AssignmentSubmissionController
    extends StateNotifier<AssignmentSubmissionState> {
  AssignmentSubmissionController(this._repository)
      : super(const AssignmentSubmissionState());

  final AssignmentSubmissionRepository _repository;

  Future<void> loadAssignment({
    required String assignmentId,
    required String studentId,
  }) async {
    if (state.assignment?.id != assignmentId) {
      state = const AssignmentSubmissionState();
    } else {
      state = state.copyWith(clearMessage: true, clearDebugMessage: true);
    }

    try {
      final StudentAssignment? assignment =
          await _repository.getAssignmentDetails(
        assignmentId: assignmentId,
        studentId: studentId,
      );

      state = state.copyWith(
        status: state.selectedFile == null
            ? AssignmentSubmissionStatus.idle
            : AssignmentSubmissionStatus.fileSelected,
        assignment: assignment,
        clearMessage: true,
        clearDebugMessage: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        status: AssignmentSubmissionStatus.error,
        message: error.message,
        debugMessage: error.details?.toString(),
      );
    } catch (error) {
      state = state.copyWith(
        status: AssignmentSubmissionStatus.error,
        message: 'Could not load assignment details. Please try again.',
        debugMessage: error.toString(),
      );
    }
  }

  Future<void> pickFile() async {
    state = state.copyWith(
      status: AssignmentSubmissionStatus.pickingFile,
      clearMessage: true,
    );

    try {
      final SelectedSubmissionFile? file =
          await _repository.pickSubmissionFile();

      state = state.copyWith(
        status: file == null
            ? AssignmentSubmissionStatus.idle
            : AssignmentSubmissionStatus.fileSelected,
        selectedFile: file,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        status: AssignmentSubmissionStatus.error,
        message: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: AssignmentSubmissionStatus.error,
        message: 'Could not select file. Please try again.',
      );
    }
  }

  Future<void> submit({
    required String assignmentId,
    required String studentId,
    String? answerText,
  }) async {
    final SelectedSubmissionFile? file = state.selectedFile;
    final StudentAssignment? assignment = state.assignment;

    if (file == null) {
      state = state.copyWith(
        status: AssignmentSubmissionStatus.error,
        message: 'Please select a file first.',
      );
      return;
    }

    if (assignment == null || !assignment.isOpen) {
      state = state.copyWith(
        status: AssignmentSubmissionStatus.error,
        message: 'This assignment is closed.',
      );
      return;
    }

    String? uploadedPath;
    state = state.copyWith(
      status: AssignmentSubmissionStatus.uploading,
      clearMessage: true,
    );

    try {
      uploadedPath = await _repository.uploadSubmissionFile(
        studentId: studentId,
        assignmentId: assignmentId,
        file: file,
      );

      final AssignmentSubmitResult submitResult =
          await _repository.submitAssignment(
        assignmentId: assignmentId,
        studentId: studentId,
        uploadedStoragePath: uploadedPath,
        answerText: answerText == null || answerText.trim().isEmpty
            ? null
            : answerText.trim(),
      );

      final StudentAssignment? refreshed =
          await _repository.getAssignmentDetails(
        assignmentId: assignmentId,
        studentId: studentId,
      );

      state = state.copyWith(
        status: AssignmentSubmissionStatus.submitted,
        assignment: refreshed,
        message: submitResult == AssignmentSubmitResult.created
            ? 'Submission uploaded successfully.'
            : 'Submission updated successfully.',
        clearSelectedFile: true,
      );
    } on AppException catch (error) {
      if (uploadedPath != null) {
        await _repository.deleteUploadedFile(uploadedPath);
      }

      state = state.copyWith(
        status: AssignmentSubmissionStatus.error,
        message: error.message,
      );
    } catch (_) {
      if (uploadedPath != null) {
        await _repository.deleteUploadedFile(uploadedPath);
      }

      state = state.copyWith(
        status: AssignmentSubmissionStatus.error,
        message:
            'Could not upload file. Please check your connection and try again.',
      );
    }
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }
}
