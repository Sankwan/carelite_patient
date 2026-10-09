import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../domain/patient_profile.dart';
import '../bloc/profile_setup_bloc.dart';
import '../bloc/profile_setup_event.dart';
import '../bloc/profile_setup_state.dart';
import '../widgets/choice_chip_group.dart';
import '../widgets/form_card.dart';
import '../widgets/labeled_field.dart';

/// Figma node 99:267. The design's prefilled date of birth is a future
/// date, which is why this uses a real picker capped at today rather than
/// a free-text field (see `_pickDateOfBirth`).
class CompleteProfilePage extends StatelessWidget {
  const CompleteProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      body: SafeArea(
        child: BlocConsumer<ProfileSetupBloc, ProfileSetupState>(
          listenWhen: (previous, current) =>
              previous.status != current.status ||
              previous.failure != current.failure,
          listener: (context, state) {
            if (state.failure != null) {
              AppToast.error(context, state.failure!.message);
            }
            if (state.status == ProfileSetupStatus.success) {
              // Tell AuthBloc the profile gate is satisfied so the router's
              // redirect stops sending this user back here, then continue
              // the funnel to the location prompt.
              context.read<AuthBloc>().add(
                    AuthProfileCompleted(fullName: state.profile.fullName),
                  );
              context.go(AppRoutes.enableLocation);
            }
          },
          builder: (context, state) {
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _Header()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList.list(
                    children: [
                      const _PhotoPicker(),
                      const SizedBox(height: AppSpacing.lg),
                      _PersonalInfoCard(profile: state.profile),
                      const SizedBox(height: AppSpacing.lg),
                      const _EmergencyContactCard(),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: 'Finish Setup',
                        isLoading: state.status == ProfileSetupStatus.submitting,
                        onPressed:
                            state.canSubmit ? () => _submit(context) : null,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    final userId = context.read<AuthBloc>().state.user?.id;
    if (userId == null) return;
    context.read<ProfileSetupBloc>().add(ProfileSubmitted(userId));
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Complete your profile', style: AppTextStyles.h1),
          SizedBox(height: AppSpacing.xs),
          Text(
            'This helps us personalise your care',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}

/// The avatar affordance from the design. Upload is deliberately deferred:
/// it needs a Supabase Storage bucket plus its own RLS path rules, which
/// land with Medical Records (requirement #4). Showing a disabled control
/// with an honest message beats a button that silently does nothing.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: 'Add a profile photo. Not available yet.',
        child: Tooltip(
          message: 'Photo upload arrives with Medical Records',
          child: DottedBorderCircle(
            onTap: () => AppToast.info(
              context,
              'Photo upload is coming soon — you can finish setup without it.',
            ),
          ),
        ),
      ),
    );
  }
}

class DottedBorderCircle extends StatelessWidget {
  const DottedBorderCircle({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        height: 96,
        width: 96,
        decoration: BoxDecoration(
          color: AppColors.lightBlueTint,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.4)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_outlined, color: AppColors.blue),
            SizedBox(height: AppSpacing.xs),
            Text('Photo', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({required this.profile});

  final PatientProfile profile;

  @override
  Widget build(BuildContext context) {
    final dob = profile.dateOfBirth;
    return FormCard(
      title: 'Personal Info',
      children: [
        LabeledField(
          label: 'Full Name',
          hintText: 'Esi Owusu',
          onChanged: (value) => context
              .read<ProfileSetupBloc>()
              .add(ProfileFullNameChanged(value)),
        ),
        LabeledField(
          label: 'Date of Birth',
          hintText: 'Select your date of birth',
          readOnly: true,
          controller: TextEditingController(
            text: dob == null ? '' : DateFormat('d MMM yyyy').format(dob),
          ),
          onTap: () => _pickDateOfBirth(context),
        ),
        Text('Gender', style: AppTextStyles.caption.copyWith(color: AppColors.ink)),
        const SizedBox(height: AppSpacing.sm),
        ChoiceChipGroup<Gender>(
          values: Gender.values,
          labelOf: (value) => value.label,
          selected: profile.gender,
          onSelected: (value) =>
              context.read<ProfileSetupBloc>().add(ProfileGenderChanged(value)),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Blood Type', style: AppTextStyles.caption.copyWith(color: AppColors.ink)),
        const SizedBox(height: AppSpacing.sm),
        ChoiceChipGroup<BloodType>(
          values: BloodType.values,
          labelOf: (value) => value.label,
          selected: profile.bloodType,
          onSelected: (value) => context
              .read<ProfileSetupBloc>()
              .add(ProfileBloodTypeChanged(value)),
        ),
      ],
    );
  }

  Future<void> _pickDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    final bloc = context.read<ProfileSetupBloc>();
    final picked = await showDatePicker(
      context: context,
      initialDate: profile.dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 120),
      // A date of birth can never be in the future — this is the guard the
      // Figma mock lacks.
      lastDate: now,
      helpText: 'Select your date of birth',
    );
    if (picked != null) {
      bloc.add(ProfileDateOfBirthChanged(picked));
    }
  }
}

class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard();

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'Emergency Contact',
      children: [
        LabeledField(
          label: 'Contact Name',
          hintText: 'e.g. Kwame Owusu',
          onChanged: (value) => context
              .read<ProfileSetupBloc>()
              .add(ProfileEmergencyContactChanged(name: value)),
        ),
        LabeledField(
          label: 'Contact Phone',
          hintText: '+233 24 456 7890',
          keyboardType: TextInputType.phone,
          onChanged: (value) => context
              .read<ProfileSetupBloc>()
              .add(ProfileEmergencyContactChanged(phone: value)),
        ),
      ],
    );
  }
}
