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
import '../../application/account_activation_controller.dart';

class ActivateAccountScreen extends ConsumerStatefulWidget {
  const ActivateAccountScreen({super.key});

  @override
  ConsumerState<ActivateAccountScreen> createState() =>
      _ActivateAccountScreenState();
}

class _ActivateAccountScreenState extends ConsumerState<ActivateAccountScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _universityNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _universityNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleActivation() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    try {
      await ref
          .read(accountActivationControllerProvider.notifier)
          .activateAccount(
            universityNumber: _universityNumberController.text,
            email: _emailController.text.trim().toLowerCase(),
            password: _passwordController.text,
          );

      if (!mounted) {
        return;
      }

      context.go(
        AppRoutes.login,
        extra:
            'Your account has been activated successfully. You can now log in.',
      );
    } on AppException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not activate account. Please check your information or contact administration.',
        );
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

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _passwordValidator(String? value) {
    final String password = value ?? '';

    if (password.isEmpty) {
      return 'Password is required.';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm your password.';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match.';
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
    final bool isLoading =
        ref.watch(accountActivationControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activate Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Image.asset(
                      AppAssets.logo,
                      width: 84,
                      height: 84,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.appName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Use your university information to activate your student account.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      controller: _universityNumberController,
                      label: 'University Number',
                      hint: 'Enter your university number',
                      prefixIcon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _emailController,
                      label: 'University Email',
                      hint: 'student@university.edu',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: 'New Password',
                      hint: 'At least 8 characters',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      hint: 'Re-enter your password',
                      prefixIcon: Icons.lock_reset_rounded,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: _confirmPasswordValidator,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Activate Account',
                      icon: Icons.verified_user_outlined,
                      isLoading: isLoading,
                      onPressed: _handleActivation,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          isLoading ? null : () => context.go(AppRoutes.login),
                      child: const Text('Back to Login'),
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
