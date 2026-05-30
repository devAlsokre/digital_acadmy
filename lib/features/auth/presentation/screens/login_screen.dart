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
              ? 'الحساب موجود، لكن لم يتم العثور على ملف طالب مرتبط به. يرجى التواصل مع إدارة الجامعة.'
              : 'هذا التطبيق متاح حاليًا للطلاب فقط.',
        );
      }

      final StudentProfile? student = await ref
          .read(studentProfileControllerProvider.notifier)
          .loadCurrentStudentProfile(force: true);

      if (student == null) {
        await ref.read(authControllerProvider.notifier).signOut();
        throw const AppException(
          'الحساب موجود، لكن لم يتم العثور على ملف طالب مرتبط به. يرجى التواصل مع إدارة الجامعة.',
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
        _showMessage('حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _isCompletingLogin = false);
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
      return 'البريد الإلكتروني مطلوب.';
    }

    final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (!emailPattern.hasMatch(email)) {
      return 'يرجى إدخال بريد إلكتروني صحيح.';
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
    final AsyncValue<void> authState = ref.watch(authControllerProvider);
    final bool isLoading = authState.isLoading || _isCompletingLogin;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            const _LoginBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const _LoginHeader(),
                        const SizedBox(height: 28),
                        _LoginPanel(
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          isLoading: isLoading,
                          emailValidator: _emailValidator,
                          requiredValidator: _requiredValidator,
                          onLogin: _handleLogin,
                          onActivateAccount: () => context.push(
                            AppRoutes.activateAccount,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _LoginFooterNote(),
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

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

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
            top: -80,
            right: -70,
            child: _DecorativeCircle(
              size: 210,
              color: AppColors.primary,
              opacity: 0.09,
            ),
          ),
          Positioned(
            top: 110,
            left: -95,
            child: _DecorativeCircle(
              size: 190,
              color: AppColors.accent,
              opacity: 0.08,
            ),
          ),
          Positioned(
            bottom: -95,
            left: -60,
            child: _DecorativeCircle(
              size: 240,
              color: AppColors.primaryDark,
              opacity: 0.08,
            ),
          ),
          Positioned(
            bottom: 110,
            right: -115,
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

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const AcademyLogo(
          variant: AcademyLogoVariant.full,
          cardSize: 150,
          logoWidth: 118,
        ),
        const SizedBox(height: 18),
        Text(
          'بوابة الطالب الرقمية',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'سجّل دخولك للوصول إلى المحاضرات والواجبات والتنبيهات',
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

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.emailValidator,
    required this.requiredValidator,
    required this.onLogin,
    required this.onActivateAccount,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final String? Function(String?) emailValidator;
  final String? Function(String?) requiredValidator;
  final VoidCallback onLogin;
  final VoidCallback onActivateAccount;

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
                    gradient: LinearGradient(
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
                    Icons.lock_open_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'تسجيل الدخول',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'أدخل بيانات حسابك الجامعي',
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
            const SizedBox(height: 24),
            AppTextField(
              controller: emailController,
              label: 'البريد الإلكتروني',
              hint: 'student@university.edu',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: emailValidator,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: passwordController,
              label: 'كلمة المرور',
              hint: 'أدخل كلمة المرور',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: requiredValidator,
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'تسجيل الدخول',
              icon: Icons.login_rounded,
              isLoading: isLoading,
              onPressed: onLogin,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: isLoading ? null : onActivateAccount,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('تفعيل الحساب'),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.softBlue.withOpacity(0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.8),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.primary.withOpacity(0.9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'استخدم البريد الإلكتروني الجامعي المزوّد من إدارة الجامعة.',
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
          ],
        ),
      ),
    );
  }
}

class _LoginFooterNote extends StatelessWidget {
  const _LoginFooterNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'أكاديميتي الرقمية · منصة تعليمية آمنة',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
