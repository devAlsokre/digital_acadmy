import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/app_user_profile.dart';

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseServiceProvider));
});

class AuthRepository {
  const AuthRepository(this._supabaseService);

  static const Duration _timeout = Duration(seconds: 12);

  final SupabaseService _supabaseService;

  SupabaseClient get _client => _supabaseService.client;

  User? get currentUser => _supabaseService.currentUser;

  Session? get currentSession => _supabaseService.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      await _client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(_timeout);
    } on AuthException catch (error) {
      throw _authExceptionToAppException(error);
    } on TimeoutException catch (error) {
      throw AppException(
        'Cannot connect to the server. Please check your network and try again.',
        details: error,
      );
    } catch (error) {
      throw AppException(
        'Something went wrong while signing in. Please try again.',
        details: error,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut().timeout(_timeout);
    } on TimeoutException catch (error) {
      throw AppException(
        'Cannot connect to the server. Please check your network and try again.',
        details: error,
      );
    } catch (error) {
      throw AppException(
        'Something went wrong while signing out. Please try again.',
        details: error,
      );
    }
  }

  Future<AppUserProfile?> getCurrentProfile() async {
    final User? user = currentUser;

    if (user == null) {
      return null;
    }

    try {
      final Map<String, dynamic>? profile = await _profileByAuthUserId(user.id);

      if (profile == null) {
        return null;
      }

      return AppUserProfile.fromJson(profile);
    } on PostgrestException catch (error) {
      if (!_isMissingAuthUserIdColumn(error)) {
        throw _databaseExceptionToAppException(error);
      }

      // Some deployments store the auth user id in profiles.id instead of
      // profiles.auth_user_id. Fall back cleanly for either schema.
      return _getProfileById(user.id);
    } on TimeoutException catch (error) {
      throw AppException(
        'Cannot connect to the server. Please check your network and try again.',
        details: error,
      );
    } catch (error) {
      throw AppException(
        'Unable to load your account profile. Please try again.',
        details: error,
      );
    }
  }

  Future<Map<String, dynamic>?> _profileByAuthUserId(String userId) async {
    final Object? response = await _client
        .from('profiles')
        .select('id, email, full_name, role, auth_user_id')
        .eq('auth_user_id', userId)
        .maybeSingle()
        .timeout(_timeout);

    return _asMap(response);
  }

  Future<AppUserProfile?> _getProfileById(String userId) async {
    try {
      final Object? response = await _client
          .from('profiles')
          .select('id, email, full_name, role')
          .eq('id', userId)
          .maybeSingle()
          .timeout(_timeout);
      final Map<String, dynamic>? profile = _asMap(response);

      if (profile == null) {
        return null;
      }

      return AppUserProfile.fromJson(profile);
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

  bool _isMissingAuthUserIdColumn(PostgrestException error) {
    final String message = error.message.toLowerCase();
    final String details = error.details?.toString().toLowerCase() ?? '';

    return error.code == '42703' ||
        (message.contains('auth_user_id') && message.contains('column')) ||
        (details.contains('auth_user_id') && details.contains('column'));
  }

  AppException _authExceptionToAppException(AuthException error) {
    final String message = error.message.toLowerCase();

    if (message.contains('invalid login credentials') ||
        error.code == 'invalid_credentials') {
      return AppException('Invalid login credentials.', details: error);
    }

    if (error is AuthRetryableFetchException ||
        error is AuthUnknownException ||
        message.contains('socket') ||
        message.contains('network')) {
      return AppException(
        'Cannot connect to the server. Please check your network and try again.',
        details: error,
      );
    }

    return AppException(
      'Unable to sign in. Please check your account and try again.',
      details: error,
    );
  }

  AppException _databaseExceptionToAppException(PostgrestException error) {
    return AppException(
      'Unable to load your account profile. Please try again.',
      details: error,
    );
  }
}
