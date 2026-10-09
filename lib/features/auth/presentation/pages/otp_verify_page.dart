import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/brand_lockup.dart';
import '../../../../core/widgets/primary_button.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/otp_code_field.dart';
import '../widgets/resend_countdown.dart';

/// Figma node 208:1274. Where the user lands after verifying is the
/// router's call, not this screen's — see [buildAppRouter]'s redirect.
class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({required this.phoneNumber, super.key});

  final String phoneNumber;

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(backgroundColor: AppColors.white, elevation: 0),
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (previous, current) => previous.failure != current.failure,
          listener: (context, state) {
            if (state.failure != null) {
              AppToast.error(context, state.failure!.message);
            }
          },
          builder: (context, state) {
            final isLoading = state.status == AuthStatus.authenticating;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BrandLockup(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('Verify your number', style: AppTextStyles.h1),
                  const SizedBox(height: AppSpacing.sm),
                  Text.rich(
                    TextSpan(
                      style: AppTextStyles.bodyMuted,
                      children: [
                        const TextSpan(text: 'Enter the 6-digit code sent to '),
                        TextSpan(
                          text: widget.phoneNumber,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  OtpCodeField(
                    controller: _otpController,
                    onCompleted: (_) => _submit(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ResendCountdown(
                    onResend: () => context
                        .read<AuthBloc>()
                        .add(AuthOtpRequested(widget.phoneNumber)),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  PrimaryButton(
                    label: 'Verify & Continue',
                    isLoading: isLoading,
                    onPressed: () => _submit(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      AppToast.warning(context, 'Enter the 6-digit code to continue.');
      return;
    }
    context.read<AuthBloc>().add(
          AuthOtpVerified(phoneNumber: widget.phoneNumber, otp: code),
        );
  }
}
