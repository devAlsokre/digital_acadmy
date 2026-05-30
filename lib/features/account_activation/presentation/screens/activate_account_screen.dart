import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/image_logo.dart';
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
            universityNumber: _universityNumberController.text.trim(),
            email: _emailController.text.trim().toLowerCase(),
            password: _passwordController.text,
          );

      if (!mounted) {
        return;
      }

      context.go(
        AppRoutes.login,
        extra: 'تم تفعيل حسابك بنجاح. يمكنك الآن تسجيل الدخول.',
      );
    } on AppException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'تعذر تفعيل الحساب. يرجى التأكد من البيانات أو التواصل مع الإدارة.',
        );
      }
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب.';
    }

    return null;
  }

  String? _emailValidator(String? value) {
    final String email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'البريد الجامعي مطلوب.';
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'يرجى إدخال بريد إلكتروني صحيح.';
    }

    return null;
  }

  String? _passwordValidator(String? value) {
    final String password = value ?? '';

    if (password.isEmpty) {
      return 'كلمة المرور مطلوبة.';
    }

    if (password.length < 8) {
      return 'يجب أن تكون كلمة المرور 8 أحرف على الأقل.';
    }

    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى تأكيد كلمة المرور.';
    }

    if (value != _passwordController.text) {
      return 'كلمتا المرور غير متطابقتين.';
    }

    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            message,
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading =
        ref.watch(accountActivationControllerProvider).isLoading;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('تفعيل الحساب'),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
        ),
        body: Stack(
          children: <Widget>[
            const _ActivationBackground(),
            SafeArea(
              top: false,
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const _ActivationHeader(),
                        const SizedBox(height: 24),
                        _ActivationPanel(
                          formKey: _formKey,
                          universityNumberController:
                              _universityNumberController,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          confirmPasswordController: _confirmPasswordController,
                          isLoading: isLoading,
                          requiredValidator: _requiredValidator,
                          emailValidator: _emailValidator,
                          passwordValidator: _passwordValidator,
                          confirmPasswordValidator: _confirmPasswordValidator,
                          onActivation: _handleActivation,
                          onBackToLogin: () => context.go(AppRoutes.login),
                        ),
                        const SizedBox(height: 18),
                        const _ActivationFooterNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivationBackground extends StatelessWidget {
  const _ActivationBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[
            Color(0xFFEAF9FF),
            Color(0xFFF7FBFF),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: Stack(
        children: const <Widget>[
          Positioned(
            top: -85,
            right: -75,
            child: _DecorativeCircle(
              size: 220,
              color: AppColors.primary,
              opacity: 0.09,
            ),
          ),
          Positioned(
            top: 140,
            left: -105,
            child: _DecorativeCircle(
              size: 195,
              color: AppColors.accent,
              opacity: 0.08,
            ),
          ),
          Positioned(
            bottom: -105,
            left: -65,
            child: _DecorativeCircle(
              size: 250,
              color: AppColors.primaryDark,
              opacity: 0.08,
            ),
          ),
          Positioned(
            bottom: 135,
            right: -120,
            child: _DecorativeCircle(
              size: 230,
              color: AppColors.accent,
              opacity: 0.07,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }
}

class _ActivationHeader extends StatelessWidget {
  const _ActivationHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const AcademyLogo(
          variant: AcademyLogoVariant.full,
          cardSize: 150,
          logoWidth: 118,
        ),
        const SizedBox(height: 16),
        Text(
          'تفعيل حساب الطالب',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'أدخل بياناتك الجامعية لإنشاء كلمة مرور وتفعيل حسابك',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
        ),
      ],
    );
  }
}

class _ActivationPanel extends StatelessWidget {
  const _ActivationPanel({
    required this.formKey,
    required this.universityNumberController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.requiredValidator,
    required this.emailValidator,
    required this.passwordValidator,
    required this.confirmPasswordValidator,
    required this.onActivation,
    required this.onBackToLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController universityNumberController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final String? Function(String?) requiredValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?) passwordValidator;
  final String? Function(String?) confirmPasswordValidator;
  final VoidCallback onActivation;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.border.withOpacity(0.95),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.10),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: <Color>[
                        AppColors.primary,
                        AppColors.accent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'بيانات التفعيل',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'تحقق من بياناتك ثم أنشئ كلمة مرور آمنة',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _ActivationStep(
              number: '1',
              title: 'البيانات الجامعية',
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: universityNumberController,
              label: 'الرقم الجامعي',
              hint: 'أدخل رقمك الجامعي',
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              validator: requiredValidator,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: emailController,
              label: 'البريد الجامعي',
              hint: 'student@university.edu',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: emailValidator,
            ),
            const SizedBox(height: 20),
            const _ActivationStep(
              number: '2',
              title: 'إنشاء كلمة المرور',
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: passwordController,
              label: 'كلمة المرور الجديدة',
              hint: '8 أحرف على الأقل',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: passwordValidator,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: confirmPasswordController,
              label: 'تأكيد كلمة المرور',
              hint: 'أعد إدخال كلمة المرور',
              prefixIcon: Icons.lock_reset_rounded,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: confirmPasswordValidator,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.softGreen.withOpacity(0.82),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.8),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.shield_outlined,
                    size: 20,
                    color: AppColors.accent.withOpacity(0.95),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'استخدم بريدك الجامعي الرسمي، واختر كلمة مرور لا تقل عن 8 أحرف.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'تفعيل الحساب',
              icon: Icons.verified_user_outlined,
              isLoading: isLoading,
              onPressed: onActivation,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: isLoading ? null : onBackToLogin,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('العودة إلى تسجيل الدخول'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivationStep extends StatelessWidget {
  const _ActivationStep({
    required this.number,
    required this.title,
  });

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.16),
            ),
          ),
          child: Text(
            number,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _ActivationFooterNote extends StatelessWidget {
  const _ActivationFooterNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'أكاديميتي الرقمية · تفعيل آمن لحساب الطالب',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
