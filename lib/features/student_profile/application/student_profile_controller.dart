import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/student_repository.dart';
import '../domain/student_profile.dart';

final StateNotifierProvider<StudentProfileController,
        AsyncValue<StudentProfile?>> studentProfileControllerProvider =
    StateNotifierProvider<StudentProfileController,
        AsyncValue<StudentProfile?>>((ref) {
  return StudentProfileController(ref.watch(studentRepositoryProvider));
});

class StudentProfileController
    extends StateNotifier<AsyncValue<StudentProfile?>> {
  StudentProfileController(this._studentRepository)
      : super(const AsyncValue.data(null));

  final StudentRepository _studentRepository;

  Future<StudentProfile?> loadCurrentStudentProfile(
      {bool force = false}) async {
    final StudentProfile? currentProfile = state.valueOrNull;

    if (!force && currentProfile != null) {
      return currentProfile;
    }

    state = const AsyncValue.loading();

    try {
      final StudentProfile? profile =
          await _studentRepository.getCurrentStudentProfile();
      state = AsyncValue.data(profile);
      return profile;
    } on AppException catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      final AppException exception = AppException(
        'Unable to load your student profile. Please try again.',
        details: error,
      );
      state = AsyncValue.error(exception, stackTrace);
      throw exception;
    }
  }
}
