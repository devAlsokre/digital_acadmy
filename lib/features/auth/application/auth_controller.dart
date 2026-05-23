import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../student_notifications/application/notification_background_sync_controller.dart';
import '../../student_profile/application/student_profile_controller.dart';
import '../data/auth_repository.dart';

final StateNotifierProvider<AuthController, AsyncValue<void>>
    authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider), ref);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._authRepository, this._ref)
      : super(const AsyncValue.data(null));

  final AuthRepository _authRepository;
  final Ref _ref;

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();

    try {
      await _authRepository.signInWithEmailAndPassword(email, password);
      state = const AsyncValue.data(null);
    } on AppException catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      final AppException exception = AppException(
        'Something went wrong while signing in. Please try again.',
        details: error,
      );
      state = AsyncValue.error(exception, stackTrace);
      throw exception;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();

    try {
      await _ref
          .read(notificationBackgroundSyncControllerProvider)
          .cancelPollingAndClearSession();
      await _authRepository.signOut();
      _ref.invalidate(studentProfileControllerProvider);
      state = const AsyncValue.data(null);
    } on AppException catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      final AppException exception = AppException(
        'Something went wrong while signing out. Please try again.',
        details: error,
      );
      state = AsyncValue.error(exception, stackTrace);
      throw exception;
    }
  }
}
