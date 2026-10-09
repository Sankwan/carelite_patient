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

/// The phone-number entry screen for phone + OTP sign-in (Figma node
/// 84:268). Not the live login: `/login` shows `EmailLoginPage`, and this
/// page is kept for when the backend adds OTP (PT-N1 in
/// docs/BACKEND_REQUESTS_PATIENT.md).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController(text: '+233 ');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              previous.status != current.status ||
              previous.failure != current.failure,
          listener: (context, state) {
            if (state.status == AuthStatus.otpSent) {
              // go_router, not Navigator.push: one navigation approach for
              // the whole app, so redirects can reason about every route.
              context.push(
                AppRoutes.otp,
                extra: _phoneController.text.trim(),
              );
            }
            if (state.failure != null) {
              AppToast.error(context, state.failure!.message);
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
                    const Text('Phone Number', style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      style: AppTextStyles.body,
                      validator: (value) {
                        if (value == null || value.trim().length < 10) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: '+233 24 456 7890',
                        hintStyle: AppTextStyles.bodyMuted,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.lg,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Send Code',
                      isLoading: isLoading,
                      onPressed: () => _submit(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      "We'll text you a 6-digit code to confirm it's you.",
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
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
    context.read<AuthBloc>().add(AuthOtpRequested(_phoneController.text.trim()));
  }
}
