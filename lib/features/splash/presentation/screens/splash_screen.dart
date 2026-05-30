import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/image_logo.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/app_user_profile.dart';
import '../../../auth/domain/app_user_role.dart';
import '../../../student_notifications/application/notification_background_sync_controller.dart';
import '../../../student_profile/application/student_profile_controller.dart';
import '../../../student_profile/domain/student_profile.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startNavigation();
  }

  Future<void> _startNavigation() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) {
      return;
    }

    await _resolveStartRoute();
  }

  Future<void> _resolveStartRoute() async {
    try {
      final AuthRepository authRepository = ref.read(authRepositoryProvider);

      if (authRepository.currentSession == null ||
          authRepository.currentUser == null) {
        _goToLogin();
        return;
      }

      final AppUserProfile? profile = await authRepository.getCurrentProfile();

      if (!mounted) {
        return;
      }

      if (profile == null) {
        await _signOutAndGoToLogin(
          'Your account exists, but no student profile was found. Please contact the university administration.',
        );
        return;
      }

      await _routeByRole(profile.role);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      _goToLogin(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _goToLogin(
        'Unable to check your session. Please sign in again.',
      );
    }
  }

  Future<void> _routeByRole(AppUserRole role) async {
    switch (role) {
      case AppUserRole.student:
        final StudentProfile? student = await ref
            .read(studentProfileControllerProvider.notifier)
            .loadCurrentStudentProfile(force: true);

        if (!mounted) {
          return;
        }

        if (student == null) {
          await _signOutAndGoToLogin(
            'Your account exists, but no student profile was found. Please contact the university administration.',
          );
          return;
        }

        try {
          await ref
              .read(notificationBackgroundSyncControllerProvider)
              .syncForStudent(student);
        } catch (_) {
          // Do not block restored sessions if Android background setup fails.
        }

        if (!mounted) {
          return;
        }

        context.go(AppRoutes.studentHome);
      case AppUserRole.teacher:
      case AppUserRole.admin:
      case AppUserRole.collegeAdmin:
        await _signOutAndGoToLogin(
          'This mobile app is currently available for students only.',
        );
      case AppUserRole.unknown:
        await _signOutAndGoToLogin(
          'Your account role is not recognized. Please contact the university administration.',
        );
    }
  }

  Future<void> _signOutAndGoToLogin(String message) async {
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (_) {
      // Continue to login even if the server is unreachable during sign out.
    }

    if (!mounted) {
      return;
    }

    _goToLogin(message);
  }

  void _goToLogin([String? message]) {
    context.go(AppRoutes.login, extra: message);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _SplashLogo(),
              SizedBox(height: 26),
              Text(
                AppStrings.appName,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppStrings.appSubtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return const AcademyLogo(
      variant: AcademyLogoVariant.full,
      cardSize: 150,
      logoWidth: 118,
    );
  }
}
