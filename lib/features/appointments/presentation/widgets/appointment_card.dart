import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../home/domain/appointment.dart';
import '../../../home/presentation/widgets/avatar_circle.dart';

/// One appointment row.
///
/// [onJoin] opens the real pre-call checklist (PT-PRECALL) on a CONFIRMED
/// appointment — the checklist and the call's ring/accept/end lifecycle are
/// live server state. Only the media transport is a stub
/// (`CallSession.join_token` is literally `stub-token-<room>`, no WebRTC
/// provider exists), and the Call screen says so plainly once the call is
/// live — see docs/PROJECT_STATUS.md.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    required this.appointment,
    this.onCancel,
    this.onJoin,
    this.isCancelling = false,
    super.key,
  });

  final Appointment appointment;
  final VoidCallback? onCancel;
  final VoidCallback? onJoin;
  final bool isCancelling;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final accent = appointment.timingAt(now) == VisitTiming.missed
        ? AppColors.error
        : _accentFor(appointment.status);
    final joinLabel = appointment.joinLabelAt(now);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarCircle(
                name: appointment.provider.displayName,
                showAvailabilityDot: true,
                isAvailable: appointment.provider.isAvailable,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      appointment.provider.displayName,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (appointment.provider.specialty != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        appointment.provider.specialty!,
                        style: AppTextStyles.bodyMuted,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      appointment.relativeLabel(),
                      style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusChip(label: appointment.statusLabelAt(now), accent: accent),
            ],
          ),
          if (onCancel != null || joinLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (joinLabel != null)
                  Expanded(
                    child: PrimaryButton(label: joinLabel, onPressed: onJoin),
                  ),
                if (joinLabel != null && onCancel != null)
                  const SizedBox(width: AppSpacing.sm),
                if (onCancel != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isCancelling ? null : onCancel,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: isCancelling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Cancel',
                              style: AppTextStyles.body.copyWith(color: AppColors.ink),
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Color _accentFor(AppointmentStatus status) => switch (status) {
        AppointmentStatus.requested => AppColors.gold,
        AppointmentStatus.confirmed => AppColors.success,
        AppointmentStatus.inProgress => AppColors.teal,
        AppointmentStatus.completed => AppColors.muted,
        AppointmentStatus.cancelled => AppColors.error,
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
        color: accent,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
