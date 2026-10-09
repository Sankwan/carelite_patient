import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/failure.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../find_clinician/presentation/pages/clinician_profile_page.dart';
import '../../../find_clinician/presentation/widgets/clinician_unavailable_sheet.dart';
import '../../../home/domain/appointment.dart';
import '../../../home/presentation/widgets/avatar_circle.dart';
import '../../domain/call_session.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';

/// PT-CALL, Phase-1 scope: real signalling (ring/accept/decline/end),
/// polled from the server, with no media rendered — the backend's own PRD
/// calls that acceptable for this phase (docs/PROJECT_STATUS.md).
/// Never shows a fake "connecting…" spinner over nothing: the moment the
/// call is live, the screen says plainly that audio/video isn't wired.
class CallPage extends StatelessWidget {
  const CallPage({required this.appointment, super.key});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CallBloc>(
      create: (_) => getIt<CallBloc>(param1: appointment.id)
        ..add(const CallStarted()),
      child: CallView(appointment: appointment),
    );
  }
}

class CallView extends StatefulWidget {
  const CallView({
    required this.appointment,
    this.ringTimeout = const Duration(seconds: 45),
    super.key,
  });

  final Appointment appointment;

  /// How long the call may ring before the patient is offered someone
  /// else. The server never times a ringing call out by itself.
  final Duration ringTimeout;

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> {
  // Redraws the elapsed-time label once a second without depending on a new
  // Bloc emission for every tick — the Bloc only emits when the server's
  // state actually changes.
  Timer? _clock;
  Timer? _ringTimer;
  bool _promptOpen = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // The listener only fires on a change; a call that is already ringing
    // when this screen opens still needs its ring timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onStateChanged(
        context,
        context.read<CallBloc>().state,
        announceFailure: false,
      );
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _ringTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: BlocConsumer<CallBloc, CallState>(
            listenWhen: (previous, current) =>
                previous.failure != current.failure ||
                previous.lifecycle != current.lifecycle ||
                previous.session?.status != current.session?.status,
            listener: _onStateChanged,
            builder: (context, state) {
              return Column(
                children: [
                  Expanded(child: _CallBody(appointment: widget.appointment, state: state)),
                  _Controls(state: state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// [announceFailure] is false for the state the screen opened with: its
  /// failure is already written on screen, so a toast would say it twice.
  void _onStateChanged(
    BuildContext context,
    CallState state, {
    bool announceFailure = true,
  }) {
    final status = state.session?.status;

    if (status == CallStatus.ringing) {
      _ringTimer ??= Timer(widget.ringTimeout, _onRingTimeout);
    } else {
      _ringTimer?.cancel();
      _ringTimer = null;
    }

    if (state.lifecycle == CallLifecycle.failed &&
        state.failure is NetworkFailure) {
      // A dropped connection is the patient's side, not the clinician's:
      // offer a retry, not a different doctor.
      _prompt(
        title: 'Your connection dropped',
        message: 'We could not reach CareLite. Check your internet and '
            'try again.',
        retryLabel: 'Try again',
        suggestOthers: false,
        onRetry: () => context.read<CallBloc>().add(const CallStarted()),
      );
      return;
    }
    if (status == CallStatus.declined || status == CallStatus.missed) {
      _prompt(
        title: '$_clinicianName can\'t take the call right now',
        message: 'You can speak to another clinician instead.',
      );
      return;
    }
    if (announceFailure && state.failure != null) {
      AppToast.error(context, state.failure!.message);
    }
  }

  void _onRingTimeout() {
    _ringTimer = null;
    if (!mounted) return;
    final bloc = context.read<CallBloc>();
    if (bloc.state.session?.status != CallStatus.ringing) return;
    _prompt(
      title: '$_clinicianName hasn\'t answered yet',
      message: 'You can keep waiting, or speak to another clinician.',
      retryLabel: 'Keep waiting',
      onRetry: () => _ringTimer = Timer(widget.ringTimeout, _onRingTimeout),
    );
  }

  String get _clinicianName => widget.appointment.provider.displayName;

  Future<void> _prompt({
    required String title,
    required String message,
    String? retryLabel,
    bool suggestOthers = true,
    VoidCallback? onRetry,
  }) async {
    if (_promptOpen || !mounted) return;
    _promptOpen = true;
    final bloc = context.read<CallBloc>();
    final navigator = Navigator.of(context);
    final provider = widget.appointment.provider;
    final choice = await showClinicianUnavailableSheet(
      context,
      title: title,
      message: message,
      retryLabel: retryLabel,
      suggestOthers: suggestOthers,
      excludeClinicianId: provider.id,
      specialty: provider.specialty,
    );
    _promptOpen = false;
    if (!mounted) return;
    switch (choice) {
      case UnavailableRetry():
        onRetry?.call();
      case UnavailablePicked(:final clinician):
        // Stop ringing the first clinician before moving to the second.
        if (bloc.state.session?.isFinished == false) {
          bloc.add(const CallEndRequested());
        }
        unawaited(navigator.pushReplacement(
          MaterialPageRoute<bool>(
            builder: (_) => ClinicianProfilePage(
              clinician: clinician,
              replacing: widget.appointment,
            ),
          ),
        ));
      case null:
        break;
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final bloc = context.read<CallBloc>();
    final session = bloc.state.session;
    if (session == null || session.isFinished) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave the call?'),
        content: const Text(
          'This will end the call for both participants.',
          style: AppTextStyles.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Stay', style: AppTextStyles.body.copyWith(color: AppColors.ink)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('End call', style: AppTextStyles.body.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (leave == true) {
      bloc.add(const CallEndRequested());
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _CallBody extends StatelessWidget {
  const _CallBody({required this.appointment, required this.state});

  final Appointment appointment;
  final CallState state;

  @override
  Widget build(BuildContext context) {
    final session = state.session;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarCircle(
              name: appointment.provider.displayName,
              size: 96,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              appointment.provider.displayName,
              style: AppTextStyles.h1.copyWith(color: AppColors.white),
            ),
            if (appointment.provider.specialty != null) ...[
              const SizedBox(height: 4),
              Text(
                appointment.provider.specialty!,
                style: AppTextStyles.body.copyWith(color: AppColors.white70),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _StatusLine(state: state),
            if (session != null && session.status == CallStatus.accepted) ...[
              const SizedBox(height: AppSpacing.md),
              _ElapsedTime(session: session),
            ],
            const SizedBox(height: AppSpacing.xl),
            const _MediaStubNotice(),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    if (state.lifecycle == CallLifecycle.failed) {
      return Text(
        state.failure?.message ?? 'Could not start the call.',
        style: AppTextStyles.body.copyWith(color: AppColors.error),
        textAlign: TextAlign.center,
      );
    }
    final session = state.session;
    final label = session == null
        ? 'Connecting…'
        : session.mode == CallMode.voice
            ? '${session.status.label} · Voice'
            : session.status.label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (session == null || session.isRinging) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white70),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          label,
          style: AppTextStyles.body.copyWith(color: AppColors.white70),
        ),
      ],
    );
  }
}

class _ElapsedTime extends StatelessWidget {
  const _ElapsedTime({required this.session});

  final CallSession session;

  @override
  Widget build(BuildContext context) {
    final elapsed = session.elapsedSince(DateTime.now()) ?? Duration.zero;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style: AppTextStyles.h2.copyWith(color: AppColors.white),
    );
  }
}

class _MediaStubNotice extends StatelessWidget {
  const _MediaStubNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: AppColors.white70, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              'Signalling only — audio and video are not connected in this '
              'build.',
              style: AppTextStyles.caption.copyWith(color: AppColors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    final finished = session?.isFinished ?? false;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: finished
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.white70),
                ),
                child: Text(
                  'Back to appointment',
                  style: AppTextStyles.body.copyWith(color: AppColors.white),
                ),
              ),
            )
          : Center(
              child: GestureDetector(
                onTap: state.lifecycle == CallLifecycle.ending
                    ? null
                    : () => context.read<CallBloc>().add(const CallEndRequested()),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: state.lifecycle == CallLifecycle.ending
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.call_end, color: AppColors.white),
                ),
              ),
            ),
    );
  }
}
