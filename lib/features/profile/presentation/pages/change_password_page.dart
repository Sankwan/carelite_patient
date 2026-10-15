import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../bloc/change_password_bloc.dart';
import '../bloc/change_password_event.dart';
import '../bloc/change_password_state.dart';

class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChangePasswordBloc>(
      create: (_) => getIt<ChangePasswordBloc>(),
      child: const ChangePasswordView(),
    );
  }
}

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Change password', style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: BlocConsumer<ChangePasswordBloc, ChangePasswordState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == ChangePasswordStatus.done) {
              AppToast.info(context, 'Password changed.');
              Navigator.of(context).pop();
            } else if (state.failure != null) {
              AppToast.error(context, state.failure!.message);
            }
          },
          builder: (context, state) {
            final submitting = state.status == ChangePasswordStatus.submitting;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthTextField(
                      label: 'Current password',
                      hintText: 'Your current password',
                      controller: _oldController,
                      obscureText: _obscureOld,
                      autofillHints: const [AutofillHints.password],
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Enter your current password'
                          : null,
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _obscureOld = !_obscureOld),
                        tooltip: _obscureOld ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscureOld
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    AuthTextField(
                      label: 'New password',
                      hintText: 'At least 8 characters',
                      controller: _newController,
                      obscureText: _obscureNew,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (value) => (value == null || value.length < 8)
                          ? 'Use at least 8 characters'
                          : null,
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                        tooltip: _obscureNew ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    AuthTextField(
                      label: 'Confirm new password',
                      hintText: 'Type it again',
                      controller: _confirmController,
                      obscureText: _obscureNew,
                      validator: (value) => value != _newController.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: 'Change password',
                      isLoading: submitting,
                      onPressed: () => _submit(context),
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<ChangePasswordBloc>().add(ChangePasswordSubmitted(
          oldPassword: _oldController.text,
          newPassword: _newController.text,
        ));
  }
}
