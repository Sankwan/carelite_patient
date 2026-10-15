import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../home/presentation/widgets/avatar_circle.dart';
import '../../domain/patient_account.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import 'change_password_page.dart';
import 'record_access_page.dart';

/// The patient's account.
///
/// Shows what the backend stores and nothing else. In particular there is no
/// name on this screen because there is no name on this backend — `username`
/// is the only human-readable identifier the API exposes (see
/// [PatientAccount]). Editing is limited to the three fields
/// `PATCH /api/accounts/me/patient-profile/` actually accepts.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Profile', style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: BlocConsumer<ProfileBloc, ProfileState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) =>
              AppToast.error(context, state.failure!.message),
          builder: (context, state) {
            if (state.status == ProfileStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  context.read<ProfileBloc>().add(const ProfileRefreshed()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (state.account != null) ...[
                    _AccountHeader(account: state.account!),
                    const SizedBox(height: AppSpacing.md),
                    _MedicalDetails(account: state.account!),
                    const SizedBox(height: AppSpacing.md),
                    _ContactDetails(account: state.account!),
                    const SizedBox(height: AppSpacing.md),
                    const _AccountActions(),
                  ] else
                    _CouldNotLoad(state: state),
                  const SizedBox(height: AppSpacing.xl),
                  const _SignOutButton(),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.account});

  final PatientAccount account;

  @override
  Widget build(BuildContext context) {
    final age = account.age;
    return _Panel(
      child: Row(
        children: [
          AvatarCircle(name: account.displayName, size: 64),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.displayName,
                  style: AppTextStyles.h2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (age != null) ...[
                  const SizedBox(height: 2),
                  Text('$age years old', style: AppTextStyles.bodyMuted),
                ],
                if (account.emergencyFlag) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Flagged for priority attention',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalDetails extends StatelessWidget {
  const _MedicalDetails({required this.account});

  final PatientAccount account;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medical details',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          _Row(
            label: 'Date of birth',
            value: account.dateOfBirthLabel ?? 'Not set',
          ),
          _Row(label: 'Sex', value: account.sex?.label ?? 'Not set'),
          _Row(label: 'Blood group', value: account.bloodGroup ?? 'Not set'),
          _Row(
            label: 'Allergies',
            value: account.allergies.trim().isEmpty
                ? 'None recorded'
                : account.allergies,
          ),
        ],
      ),
    );
  }
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails({required this.account});

  final PatientAccount account;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          _Row(
            label: 'Email',
            value: account.email.trim().isEmpty ? 'Not set' : account.email,
          ),
          _Row(
            label: 'Phone',
            value: account.phone.trim().isEmpty ? 'Not set' : account.phone,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Stated rather than silently omitted: Complete Profile asks for an
          // emergency contact, but PatientProfile has only an
          // `emergency_flag` boolean — there is no name or phone field to
          // save one into. Flagged for the backend team in
          // docs/PROJECT_STATUS.md.
          const Text(
            'Emergency contact details cannot be stored yet — the backend has '
            'no field for them.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _AccountActions extends StatelessWidget {
  const _AccountActions();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ActionRow(
            icon: Icons.lock_outline,
            label: 'Change password',
            onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
              MaterialPageRoute<void>(builder: (_) => const ChangePasswordPage()),
            ),
          ),
          _ActionRow(
            icon: Icons.shield_outlined,
            label: 'Who can see my record',
            onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
              MaterialPageRoute<void>(builder: (_) => const RecordAccessPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.muted),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTextStyles.body)),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppTextStyles.bodyMuted),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTextStyles.body,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _CouldNotLoad extends StatelessWidget {
  const _CouldNotLoad({required this.state});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load your profile',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.failure?.message ?? 'Please try again.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () =>
                context.read<ProfileBloc>().add(const ProfileRefreshed()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: AppColors.teal),
            ),
            child: Text(
              'Try again',
              style: AppTextStyles.body.copyWith(color: AppColors.tealText),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _confirm(context),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.error),
        ),
        child: Text(
          'Sign out',
          style: AppTextStyles.body.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need your password to sign back in.',
          style: AppTextStyles.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Stay signed in',
              style: AppTextStyles.body.copyWith(color: AppColors.ink),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Sign out',
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) authBloc.add(const AuthSignOutRequested());
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
