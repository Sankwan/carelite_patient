import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../home/presentation/widgets/avatar_circle.dart';
import '../../domain/call_session.dart';
import '../bloc/incoming_call_bloc.dart';
import '../bloc/incoming_call_event.dart';
import '../bloc/incoming_call_state.dart';
import 'call_page.dart';
import 'precall_page.dart';

/// Full-screen ringing for a call the clinician started.
///
/// Opened by the live socket when an INCOMING_CALL notification arrives, so
/// it only rings while the app is open. Ringing a closed app needs real
/// push delivery, which the backend does not send yet.
class IncomingCallPage extends StatelessWidget {
  const IncomingCallPage({required this.callId, super.key});

  final String callId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IncomingCallBloc>(
      create: (_) => getIt<IncomingCallBloc>(param1: callId)
        ..add(const IncomingCallStarted()),
      child: const IncomingCallView(),
    );
  }
}

class IncomingCallView extends StatelessWidget {
  const IncomingCallView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: BlocConsumer<IncomingCallBloc, IncomingCallState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: _onStatusChanged,
          builder: (context, state) {
            final appointment = state.appointment;
            if (appointment == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.white70),
              );
            }
            final provider = appointment.provider;
            final isVoice = state.session?.mode == CallMode.voice;
            return Column(
              children: [
                const Spacer(),
                AvatarCircle(name: provider.displayName, size: 112),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  provider.displayName,
                  style: AppTextStyles.h1.copyWith(color: AppColors.white),
                  textAlign: TextAlign.center,
                ),
                if (provider.specialty != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    provider.specialty!,
                    style: AppTextStyles.body.copyWith(color: AppColors.white70),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  isVoice ? 'Incoming voice call' : 'Incoming video call',
                  style: AppTextStyles.body.copyWith(color: AppColors.white70),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundAction(
                        label: 'Decline',
                        icon: Icons.call_end,
                        color: AppColors.error,
                        busy: state.status == IncomingCallStatus.declining,
                        onTap: state.status == IncomingCallStatus.ringing
                            ? () => context
                                .read<IncomingCallBloc>()
                                .add(const IncomingCallDeclined())
                            : null,
                      ),
                      _RoundAction(
                        label: 'Answer',
                        icon: isVoice ? Icons.call : Icons.videocam,
                        color: AppColors.teal,
                        onTap: state.status == IncomingCallStatus.ringing
                            ? () => _answer(context, state)
                            : null,
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

  void _onStatusChanged(BuildContext context, IncomingCallState state) {
    switch (state.status) {
      case IncomingCallStatus.over:
        final session = state.session;
        // Declining here closes quietly; anything else the patient did not
        // choose deserves a word.
        if (session != null && session.status != CallStatus.declined) {
          final name = state.appointment?.provider.displayName;
          AppToast.info(
            context,
            name == null ? 'The call ended.' : 'Missed call from $name',
          );
        }
        Navigator.of(context).maybePop();
      case IncomingCallStatus.failed:
        AppToast.error(
          context,
          state.failure?.message ?? 'We could not load this call.',
        );
        Navigator.of(context).maybePop();
      case _:
        break;
    }
  }

  /// The server will not let the patient answer before the checklist, so
  /// Answer goes through it when needed. Either way this screen is
  /// replaced: Back from the call returns to where the patient was.
  void _answer(BuildContext context, IncomingCallState state) {
    final appointment = state.appointment!;
    final callId = context.read<IncomingCallBloc>().callId;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => state.needsPrecall
            ? PrecallPage(appointment: appointment, answeringCallId: callId)
            : CallPage(appointment: appointment, answeringCallId: callId),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Icon(icon, color: AppColors.white, size: 30),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: AppTextStyles.body.copyWith(color: AppColors.white)),
          ],
        ),
      ),
    );
  }
}
