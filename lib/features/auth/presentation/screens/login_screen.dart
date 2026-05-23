import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../student_notifications/application/notification_background_sync_controller.dart';
import '../../../student_profile/application/student_profile_controller.dart';
import '../../../student_profile/domain/student_profile.dart';
import '../../application/auth_controller.dart';
import '../../data/auth_repository.dart';
import '../../domain/app_user_profile.dart';
import '../../domain/app_user_role.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.message});

  final String? message;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isCompletingLogin = false;

  @override
  void initState() {
    super.initState();

    if (widget.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _showMessage(widget.message!);
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() => _isCompletingLogin = true);

    try {
      await ref.read(authControllerProvider.notifier).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );

      final AuthRepository authRepository = ref.read(authRepositoryProvider);
      final AppUserProfile? profile = await authRepository.getCurrentProfile();

      if (profile == null || profile.role != AppUserRole.student) {
        await ref.read(authControllerProvider.notifier).signOut();
        throw AppException(
          profile == null
              ? 'Your account exists, but no student profile was found. Please contact the university administration.'
              : 'This mobile app is currently available for students only.',
        );
      }

      final StudentProfile? student = await ref
          .read(studentProfileControllerProvider.notifier)
          .loadCurrentStudentProfile(force: true);

      if (student == null) {
        await ref.read(authControllerProvider.notifier).signOut();
        throw const AppException(
          'Your account exists, but no student profile was found. Please contact the university administration.',
        );
      }

      try {
        await ref
            .read(notificationBackgroundSyncControllerProvider)
            .syncForStudent(student);
      } catch (_) {
        // Background alerts are helpful, but login should still succeed.
      }

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.studentHome);
    } on AppException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Unknown error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isCompletingLogin = false);
      }
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _emailValidator(String? value) {
    final String email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email is required.';
    }

    final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> authState = ref.watch(authControllerProvider);
    final bool isLoading = authState.isLoading || _isCompletingLogin;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _LoginHeader(),
                    const SizedBox(height: 34),
                    AppTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'student@university.edu',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: 'Login',
                      icon: Icons.login_rounded,
                      isLoading: isLoading,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Use your university email provided by the university.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Image.asset(
          AppAssets.logo,
          width: 108,
          height: 108,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 22),
        Text(
          AppStrings.appName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.appSubtitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
