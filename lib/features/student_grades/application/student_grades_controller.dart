import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../student_profile/application/student_profile_controller.dart';
import '../../student_profile/domain/student_profile.dart';
import '../data/student_grades_repository.dart';
import '../domain/student_course_grades.dart';

final StateNotifierProvider<StudentGradesController,
        AsyncValue<List<StudentCourseGrades>>> studentGradesControllerProvider =
    StateNotifierProvider<StudentGradesController,
        AsyncValue<List<StudentCourseGrades>>>((ref) {
  return StudentGradesController(
    ref.watch(studentGradesRepositoryProvider),
    ref,
  );
});

class StudentGradesController
    extends StateNotifier<AsyncValue<List<StudentCourseGrades>>> {
  StudentGradesController(this._repository, this._ref)
      : super(const AsyncValue.data(<StudentCourseGrades>[]));

  final StudentGradesRepository _repository;
  final Ref _ref;

  Future<List<StudentCourseGrades>> loadGrades({bool force = false}) async {
    final List<StudentCourseGrades>? currentGrades = state.valueOrNull;

    if (!force && currentGrades != null && currentGrades.isNotEmpty) {
      return currentGrades;
    }

    state = const AsyncValue.loading();

    try {
      final StudentProfile? student =
          _ref.read(studentProfileControllerProvider).valueOrNull ??
              await _ref
                  .read(studentProfileControllerProvider.notifier)
                  .loadCurrentStudentProfile(force: force);

      if (student == null) {
        state = const AsyncValue.data(<StudentCourseGrades>[]);
        return <StudentCourseGrades>[];
      }

      final List<StudentCourseGrades> grades =
          await _repository.getMyPublishedGrades(studentId: student.id);
      state = AsyncValue.data(grades);
      return grades;
    } on AppException catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      final AppException exception = AppException(
        'Could not load grades. Please try again.',
        details: error,
      );
      state = AsyncValue.error(exception, stackTrace);
      throw exception;
    }
  }

  Future<void> refresh() async {
    await loadGrades(force: true);
  }
}
