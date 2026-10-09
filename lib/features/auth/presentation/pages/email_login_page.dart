import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/brand_lockup.dart';
import '../../../../core/widgets/primary_button.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_text_field.dart';

/// Email + password sign-in — the one auth path live on both ends today.
///
/// The Figma login screen shows a password field, which this finally
/// implements; the phone+OTP route survives as the "no email" fallback and
/// is gated on the backend shipping its OTP endpoints. Rather than hide that
/// affordance, it stays visible and reports honestly when tapped, so the
/// product direction remains discoverable.
class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (previous, current) => previous.failure != current.failure,
          listener: (context, state) {
            final failure = state.failure;
            if (failure != null) {
              AppToast.error(context, failure.message);
            }
          },
          builder: (context, state) {
            final isLoading = state.status == AuthStatus.authenticating;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: BrandLockup(),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const Text('Welcome back', style: AppTextStyles.h1),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Log in to your health account',
                      style: AppTextStyles.bodyMuted,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AuthTextField(
                      label: 'Email',
                      hintText: 'you@example.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.email,
                        AutofillHints.username,
                      ],
                      // Not an email-format check: the backend authenticates
                      // on `username`, and this app posts whatever is typed
                      // here under that field (see DjangoAuthRepository /
                      // docs/PROJECT_STATUS.md). For this app's own
                      // accounts that value is always an email, because
                      // registerWithEmail sets username == email — but a
                      // seeded/demo account's username (e.g. "kofi") is not
                      // email-shaped and must still be accepted. Requiring
                      // "@" here previously rejected every one of them.
                      validator: _validateCredential,
                    ),
                    AuthTextField(
                      label: 'Password',
                      hintText: 'Your password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      validator: (value) =>
                          (value == null || value.isEmpty)
                              ? 'Enter your password'
                              : null,
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrimaryButton(
                      label: 'Log In',
                      isLoading: isLoading,
                      onPressed: () => _submit(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _OrDivider(),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton(
                      onPressed: isLoading ? null : () => _usePhoneInstead(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                      ),
                      child: Text(
                        "I don't have an email",
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('New to CareLite? ',
                            style: AppTextStyles.bodyMuted),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.register),
                          child: Text(
                            'Create account',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState?.validate() != true) return;
    context.read<AuthBloc>().add(
          AuthEmailSignInRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  /// The OTP route exists and is wired, but the backend has no endpoints
  /// behind it. Saying so is better than a dead button or a screen that
  /// waits forever for a code that will never arrive.
  void _usePhoneInstead(BuildContext context) {
    AppToast.info(
      context,
      'Phone sign-in is coming soon. Please use your email and password '
      'for now.',
    );
  }

  /// Deliberately not an email-format check — see the field's own comment.
  static String? _validateCredential(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Enter your email';
    return null;
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('or continue with phone number', style: AppTextStyles.caption),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
