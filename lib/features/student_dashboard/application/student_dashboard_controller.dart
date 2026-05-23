import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../student_profile/domain/student_profile.dart';
import '../data/student_dashboard_repository.dart';
import '../domain/student_dashboard_data.dart';

final StateNotifierProvider<StudentDashboardController,
        AsyncValue<StudentDashboardData?>> studentDashboardControllerProvider =
    StateNotifierProvider<StudentDashboardController,
        AsyncValue<StudentDashboardData?>>((ref) {
  return StudentDashboardController(
    ref.watch(studentDashboardRepositoryProvider),
  );
});

class StudentDashboardController
    extends StateNotifier<AsyncValue<StudentDashboardData?>> {
  StudentDashboardController(this._repository)
      : super(const AsyncValue.data(null));

  final StudentDashboardRepository _repository;

  Future<StudentDashboardData?> loadDashboard(
    StudentProfile student, {
    bool force = false,
  }) async {
    final StudentDashboardData? currentData = state.valueOrNull;

    if (!force && currentData != null) {
      return currentData;
    }

    state = const AsyncValue.loading();

    try {
      final StudentDashboardData data =
          await _repository.getDashboardData(student);
      state = AsyncValue.data(data);
      return data;
    } on AppException catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      final AppException exception = AppException(
        'Could not load dashboard data. Please try again.',
        details: error,
      );
      state = AsyncValue.error(exception, stackTrace);
      throw exception;
    }
  }

  Future<void> refresh(StudentProfile student) async {
    await loadDashboard(student, force: true);
  }
}
