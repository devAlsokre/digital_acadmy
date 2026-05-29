import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/account_activation_repository.dart';

final StateNotifierProvider<AccountActivationController, AsyncValue<void>>
    accountActivationControllerProvider =
    StateNotifierProvider<AccountActivationController, AsyncValue<void>>(
  (ref) {
    return AccountActivationController(
      ref.watch(accountActivationRepositoryProvider),
    );
  },
);

class AccountActivationController extends StateNotifier<AsyncValue<void>> {
  AccountActivationController(this._repository)
      : super(const AsyncValue.data(null));

  final AccountActivationRepository _repository;

  Future<void> activateAccount({
    required String universityNumber,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();

    try {
      await _repository.activateAccount(
        universityNumber: universityNumber,
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } on AppException catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      final AppException exception = AppException(
        'Could not activate account. Please check your information or contact administration.',
        details: error,
      );
      state = AsyncValue.error(exception, stackTrace);
      throw exception;
    }
  }
}
