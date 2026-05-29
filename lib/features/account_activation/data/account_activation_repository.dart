import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/activation_api_config.dart';
import '../../../core/errors/app_exception.dart';

final Provider<AccountActivationRepository>
    accountActivationRepositoryProvider =
    Provider<AccountActivationRepository>((ref) {
  return const AccountActivationRepository();
});

class AccountActivationRepository {
  const AccountActivationRepository();

  static const Duration _requestTimeout = Duration(seconds: 15);

  Future<void> activateAccount({
    required String universityNumber,
    required String email,
    required String password,
  }) async {
    if (!ActivationApiConfig.isConfigured) {
      throw const AppException('Activation service is not configured.');
    }

    final Uri? endpoint =
        Uri.tryParse(ActivationApiConfig.activationUrl.trim());
    if (endpoint == null || !endpoint.hasScheme || !endpoint.hasAuthority) {
      throw const AppException('Activation service is not configured.');
    }

    final HttpClient client = HttpClient();

    try {
      final HttpClientRequest request =
          await client.postUrl(endpoint).timeout(_requestTimeout);

      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, String>{
          'university_number': universityNumber.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      final HttpClientResponse response =
          await request.close().timeout(_requestTimeout);
      await response.drain<void>().timeout(_requestTimeout);

      if (response.statusCode == HttpStatus.ok ||
          response.statusCode == HttpStatus.created) {
        return;
      }

      if (response.statusCode == HttpStatus.conflict) {
        throw const AppException(
          'This account is already activated. Please log in.',
        );
      }

      if (response.statusCode >= HttpStatus.internalServerError) {
        throw const AppException(
          'Activation service error. Please try again later.',
        );
      }

      throw const AppException(
        'Could not activate account. Please check your information or contact administration.',
      );
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException(
        'Could not connect to the activation service.',
      );
    } on SocketException {
      throw const AppException(
        'Could not connect to the activation service.',
      );
    } on FormatException {
      throw const AppException('Activation service is not configured.');
    } catch (_) {
      throw const AppException(
        'Could not activate account. Please check your information or contact administration.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
