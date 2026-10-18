import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../home/domain/appointment.dart';
import '../../../home/presentation/widgets/avatar_circle.dart';
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
///
/// With [answeringCallId], Join answers that ringing call rather than
/// starting a new one.
class PrecallPage extends StatelessWidget {
  const PrecallPage(
      {required this.appointment, this.answeringCallId, super.key});

  final Appointment appointment;
  final String? answeringCallId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PrecallBloc>(
      create: (_) => getIt<PrecallBloc>(param1: appointment.id)
        ..add(const PrecallStarted()),
      child: PrecallView(
        appointment: appointment,
        answeringCallId: answeringCallId,
      ),
    );
  }
}

class PrecallView extends StatelessWidget {
  const PrecallView(
      {required this.appointment, this.answeringCallId, super.key});

  final Appointment appointment;
  final String? answeringCallId;

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
            final checklist = state.checklist;
            final confirmed = [
              checklist.quietLocation,
              checklist.cameraMicOk,
              checklist.connectionOk,
              checklist.documentsReady,
            ].where((done) => done).length;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _AppointmentSummary(appointment: appointment),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(
                            child: Text(
                              'Confirm before you join',
                              style: AppTextStyles.h2,
                            ),
                          ),
                          Text(
                            '$confirmed of $_itemCount',
                            style: AppTextStyles.caption.copyWith(
                              color: confirmed == _itemCount
                                  ? AppColors.success
                                  : AppColors.tealText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                        child: LinearProgressIndicator(
                          value: confirmed / _itemCount,
                          minHeight: 6,
                          backgroundColor: AppColors.lightTealTint,
                          color: confirmed == _itemCount
                              ? AppColors.success
                              : AppColors.teal,
                        ),
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
                        hint:
                            'Somewhere you can talk openly about your health.',
                        checked: state.checklist.quietLocation,
                        onChanged: () => context.read<PrecallBloc>().add(
                            const PrecallItemToggled(
                                PrecallItem.quietLocation)),
                      ),
                      _ChecklistTile(
                        icon: Icons.videocam_outlined,
                        title: 'My camera and microphone work',
                        hint:
                            'Your clinician needs to see and hear you clearly.',
                        checked: state.checklist.cameraMicOk,
                        onChanged: () => context.read<PrecallBloc>().add(
                            const PrecallItemToggled(PrecallItem.cameraMicOk)),
                      ),
                      _ChecklistTile(
                        icon: Icons.wifi,
                        title: 'My connection feels stable',
                        hint: 'Wi-Fi is best. Stay close to your router.',
                        checked: state.checklist.connectionOk,
                        onChanged: () => context.read<PrecallBloc>().add(
                            const PrecallItemToggled(PrecallItem.connectionOk)),
                      ),
                      _ChecklistTile(
                        icon: Icons.folder_outlined,
                        title: 'I have any documents or results on hand',
                        hint: 'Prescriptions, lab results or notes to discuss.',
                        checked: state.checklist.documentsReady,
                        onChanged: () => context.read<PrecallBloc>().add(
                            const PrecallItemToggled(
                                PrecallItem.documentsReady)),
                      ),
                      if (state.serverStatus.youAcknowledged) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _ReadinessBanner(
                          serverStatus: state.serverStatus,
                          clinicianName: appointment.provider.displayName,
                          isAnswering: answeringCallId != null,
                        ),
                      ],
                    ],
                  ),
                ),
                _BottomBar(
                  appointment: appointment,
                  answeringCallId: answeringCallId,
                  state: state,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Matches the four fields of [PrecallChecklist].
const _itemCount = 4;

class _AppointmentSummary extends StatelessWidget {
  const _AppointmentSummary({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final provider = appointment.provider;
    final isVoice = appointment.consultationType == ConsultationKind.voice;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Row(
        children: [
          AvatarCircle(name: provider.displayName, size: 56),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consultation with ${provider.displayName}',
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                if (provider.specialty != null) ...[
                  const SizedBox(height: 2),
                  Text(provider.specialty!, style: AppTextStyles.bodyMuted),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      isVoice ? Icons.call_outlined : Icons.videocam_outlined,
                      size: 16,
                      color: AppColors.tealText,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        appointment.relativeLabel(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.tealText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.icon,
    required this.title,
    required this.hint,
    required this.checked,
    required this.onChanged,
  });

  final IconData icon;
  final String title;

  /// One line on why the item matters, so it reads as preparation rather
  /// than a form to tick through.
  final String hint;
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
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrayBg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.muted),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(hint, style: AppTextStyles.bodyMuted),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  checked ? Icons.check_circle : Icons.circle_outlined,
                  size: 26,
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
  const _ReadinessBanner({
    required this.serverStatus,
    required this.clinicianName,
    required this.isAnswering,
  });

  final PrecallStatus serverStatus;
  final String clinicianName;

  /// Answering the clinician's call, rather than waiting for one.
  final bool isAnswering;

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
              switch ((isAnswering, bothReady)) {
                (true, _) => 'You\'re ready. Join $clinicianName now.',
                // The clinician leads: they call when they start.
                (false, true) => 'You\'re both ready. $clinicianName will call you here.',
                (false, false) => 'You\'re ready. $clinicianName will call you here, '
                    'so keep this screen open.',
              },
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
  const _BottomBar({
    required this.appointment,
    required this.answeringCallId,
    required this.state,
  });

  final Appointment appointment;
  final String? answeringCallId;
  final PrecallState state;

  @override
  Widget build(BuildContext context) {
    final acknowledged = state.serverStatus.youAcknowledged;
    final now = DateTime.now();
    // The clinician calls first. The patient can call too once the booked
    // time has come (the clinician may be running late) or the visit is
    // under way; answering a call is always allowed.
    final mayCall = answeringCallId != null ||
        appointment.timingAt(now) == VisitTiming.live ||
        !now.isBefore(appointment.dueAt);
    final canJoin = acknowledged && mayCall;
    final waiting = acknowledged && !mayCall;
    final blocked = !acknowledged && !state.checklist.isComplete;
    final clinician = appointment.provider.displayName;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (blocked) ...[
            const Text(
              'Tick every item above to continue',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canJoin
                  ? () => _openCall(context)
                  : waiting
                  ? null
                  : (state.canSubmit
                      ? () => context
                          .read<PrecallBloc>()
                          .add(const PrecallSubmitted())
                      : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
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
                      switch ((canJoin, waiting)) {
                        (true, _) when answeringCallId != null => 'Join Call',
                        (true, _) => 'Call $clinician',
                        (_, true) =>
                          'Waiting for $clinician to call · ${DateFormat('h:mm a').format(appointment.dueAt)}',
                        _ => 'Confirm and continue',
                      },
                      // Waiting is a state, not a dead button: readable grey.
                      style: waiting
                          ? AppTextStyles.buttonLabel
                              .copyWith(color: AppColors.muted)
                          : AppTextStyles.buttonLabel,
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCall(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CallPage(
          appointment: appointment,
          answeringCallId: answeringCallId,
        ),
      ),
    );
  }
}
