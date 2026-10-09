import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../home/domain/appointment.dart';
import '../../domain/precall_checklist.dart';
import '../bloc/precall_bloc.dart';
import '../bloc/precall_event.dart';
import '../bloc/precall_state.dart';
import 'call_page.dart';

/// PT-PRECALL: the acknowledgement gate before a call can start.
///
/// "Join Call" stays disabled until every item is ticked — a gate, not a
/// toast, per the backend's own acceptance criterion. Ticking here is
/// entirely local until Confirm is pressed; only Confirm talks to the
/// server, matching the server's own all-or-nothing validation.
class PrecallPage extends StatelessWidget {
  const PrecallPage({required this.appointment, super.key});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PrecallBloc>(
      create: (_) => getIt<PrecallBloc>(param1: appointment.id)
        ..add(const PrecallStarted()),
      child: PrecallView(appointment: appointment),
    );
  }
}

class PrecallView extends StatelessWidget {
  const PrecallView({required this.appointment, super.key});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Before you join', style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: BlocConsumer<PrecallBloc, PrecallState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) =>
              AppToast.error(context, state.failure!.message),
          builder: (context, state) {
            if (state.status == PrecallStepStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _AppointmentSummary(appointment: appointment),
                      const SizedBox(height: AppSpacing.xl),
                      const Text(
                        'Confirm before you join',
                        style: AppTextStyles.h2,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'All four must be confirmed to start the call.',
                        style: AppTextStyles.bodyMuted,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _ChecklistTile(
                        icon: Icons.volume_off_outlined,
                        title: 'I\'m in a quiet, private location',
                        checked: state.checklist.quietLocation,
                        onChanged: () => context
                            .read<PrecallBloc>()
                            .add(const PrecallItemToggled(
                                PrecallItem.quietLocation)),
                      ),
                      _ChecklistTile(
                        icon: Icons.videocam_outlined,
                        title: 'My camera and microphone work',
                        checked: state.checklist.cameraMicOk,
                        onChanged: () => context
                            .read<PrecallBloc>()
                            .add(const PrecallItemToggled(
                                PrecallItem.cameraMicOk)),
                      ),
                      _ChecklistTile(
                        icon: Icons.wifi,
                        title: 'My connection feels stable',
                        checked: state.checklist.connectionOk,
                        onChanged: () => context
                            .read<PrecallBloc>()
                            .add(const PrecallItemToggled(
                                PrecallItem.connectionOk)),
                      ),
                      _ChecklistTile(
                        icon: Icons.folder_outlined,
                        title: 'I have any documents or results on hand',
                        checked: state.checklist.documentsReady,
                        onChanged: () => context
                            .read<PrecallBloc>()
                            .add(const PrecallItemToggled(
                                PrecallItem.documentsReady)),
                      ),
                      if (state.serverStatus.youAcknowledged) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _ReadinessBanner(serverStatus: state.serverStatus),
                      ],
                    ],
                  ),
                ),
                _BottomBar(appointment: appointment, state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppointmentSummary extends StatelessWidget {
  const _AppointmentSummary({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consultation with ${appointment.provider.displayName}',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          if (appointment.provider.specialty != null) ...[
            const SizedBox(height: 2),
            Text(appointment.provider.specialty!, style: AppTextStyles.bodyMuted),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(appointment.relativeLabel(), style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.icon,
    required this.title,
    required this.checked,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        checked: checked,
        button: true,
        child: InkWell(
          onTap: onChanged,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: checked ? AppColors.lightTealTint : AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: checked ? AppColors.teal : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: checked ? AppColors.teal : AppColors.muted,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(title, style: AppTextStyles.body),
                ),
                Icon(
                  checked ? Icons.check_circle : Icons.circle_outlined,
                  color: checked ? AppColors.teal : AppColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadinessBanner extends StatelessWidget {
  const _ReadinessBanner({required this.serverStatus});

  final PrecallStatus serverStatus;

  @override
  Widget build(BuildContext context) {
    final bothReady = serverStatus.bothReady;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bothReady ? AppColors.successBg : AppColors.goldBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            bothReady ? Icons.check_circle : Icons.hourglass_top,
            color: bothReady ? AppColors.success : AppColors.goldText,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              bothReady
                  ? 'You\'re both ready to join.'
                  : 'You\'re confirmed. Waiting for the clinician to '
                      'complete their checklist too.',
              style: AppTextStyles.caption.copyWith(
                color: bothReady ? AppColors.success : AppColors.goldText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.appointment, required this.state});

  final Appointment appointment;
  final PrecallState state;

  @override
  Widget build(BuildContext context) {
    final canJoin = state.serverStatus.youAcknowledged;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canJoin
              ? () => _openCall(context)
              : (state.canSubmit
                  ? () => context.read<PrecallBloc>().add(const PrecallSubmitted())
                  : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            disabledBackgroundColor: AppColors.border,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
          ),
          child: state.status == PrecallStepStatus.submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : Text(
                  canJoin ? 'Join Call' : 'Confirm and continue',
                  style: AppTextStyles.buttonLabel,
                ),
        ),
      ),
    );
  }

  void _openCall(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CallPage(appointment: appointment),
      ),
    );
  }
}
