import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/display_name.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../domain/access_request.dart';
import '../bloc/access_requests_bloc.dart';
import '../bloc/access_requests_event.dart';
import '../bloc/access_requests_state.dart';

/// Who has asked to see this patient's details, and who can right now.
///
/// Consultation access (a booked appointment) is separate and always
/// granted — this is the extra consent layer a clinician needs for the
/// patient's wider file. See docs/BACKEND_REQUESTS_PATIENT.md PT-N12.
class RecordAccessPage extends StatelessWidget {
  const RecordAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccessRequestsBloc>(
      create: (_) =>
          getIt<AccessRequestsBloc>()..add(const AccessRequestsStarted()),
      child: const RecordAccessView(),
    );
  }
}

class RecordAccessView extends StatelessWidget {
  const RecordAccessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Who can see my record', style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: BlocConsumer<AccessRequestsBloc, AccessRequestsState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) =>
              AppToast.error(context, state.failure!.message),
          builder: (context, state) {
            if (state.status == AccessRequestsStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.requests.isEmpty) return const _EmptyState();
            return RefreshIndicator(
              onRefresh: () async => context
                  .read<AccessRequestsBloc>()
                  .add(const AccessRequestsRefreshed()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (state.pending.isNotEmpty) ...[
                    const _SectionHeader('Waiting for your decision'),
                    for (final request in state.pending) ...[
                      _RequestCard(
                        request: request,
                        busy: state.decidingId == request.id,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (state.decided.isNotEmpty) ...[
                    const _SectionHeader('Decided'),
                    for (final request in state.decided) ...[
                      _RequestCard(
                        request: request,
                        busy: state.decidingId == request.id,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.busy});

  final AccessRequest request;
  final bool busy;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatUsername(request.clinicianUsername),
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _StatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 2),
          Text('Requested ${request.requestedAtLabel}', style: AppTextStyles.caption),
          if (request.reason.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(request.reason, style: AppTextStyles.bodyMuted),
          ],
          const SizedBox(height: AppSpacing.md),
          _Actions(request: request, busy: busy),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.request, required this.busy});

  final AccessRequest request;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (request.isPending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _decide(context, AccessDecision.decline),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Text('Decline', style: AppTextStyles.body),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _decide(context, AccessDecision.approve),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                minimumSize: const Size(0, 40),
              ),
              child: Text(
                'Approve',
                style: AppTextStyles.body.copyWith(color: AppColors.white),
              ),
            ),
          ),
        ],
      );
    }
    if (request.isActive) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => _decide(context, AccessDecision.revoke),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            side: const BorderSide(color: AppColors.error),
          ),
          child: Text(
            'Revoke access',
            style: AppTextStyles.body.copyWith(color: AppColors.error),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _decide(BuildContext context, AccessDecision decision) {
    context
        .read<AccessRequestsBloc>()
        .add(AccessRequestDecided(request.id, decision));
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AccessRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AccessRequestStatus.pending => AppColors.goldText,
      AccessRequestStatus.active => AppColors.tealText,
      AccessRequestStatus.inactive => AppColors.muted,
    };
    return Text(
      status.label,
      style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 48, color: AppColors.muted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No one has requested access',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'When a clinician asks to view your details beyond a booked '
              'appointment, you will decide here.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
