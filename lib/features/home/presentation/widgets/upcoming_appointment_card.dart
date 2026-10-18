import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/appointment.dart';
import 'rating_badge.dart';

/// The teal hero card. Shown only to a returning patient — a brand-new
/// patient must never see an "Upcoming Appointment" section (requirement #6).
class UpcomingAppointmentCard extends StatelessWidget {
  const UpcomingAppointmentCard({
    required this.appointment,
    required this.onJoin,
    super.key,
  });

  final Appointment appointment;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final provider = appointment.provider;
    final rating = provider.rating;
    final now = DateTime.now();
    final timing = appointment.timingAt(now);
    final isLive = timing == VisitTiming.live;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isLive) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                isLive ? 'CONSULTATION IN PROGRESS' : 'UPCOMING APPOINTMENT',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.white,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.displayName,
                      style: AppTextStyles.h1.copyWith(color: AppColors.white),
                    ),
                    if (provider.specialty != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        // Same field the list below renders — one specialty
                        // per provider, everywhere.
                        provider.specialty!,
                        style: AppTextStyles.bodyMuted.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (rating != null) RatingBadge(rating: rating, onDark: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _IconLabel(
                icon: Icons.schedule,
                // Computed from the stored DateTime, never a fixed string.
                label: appointment.relativeLabel(),
              ),
              _IconLabel(
                icon: Icons.videocam_outlined,
                label: appointment.consultationType.label,
              ),
            ],
          ),
          if (appointment.escrowStatus == 'held') ...[
            const SizedBox(height: AppSpacing.md),
            // Read-only mirror of the Care Cycle Service's ledger (§7). The
            // app displays escrow state and never computes or changes it.
            const _IconLabel(
              icon: Icons.lock_outline,
              label: 'Payment held securely until your consultation is complete',
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
              ),
              child: Text(
                // REQUESTED appointments cannot be joined yet — the clinician
                // has not confirmed — so the button reflects that honestly
                // instead of offering a call that will fail.
                appointment.joinLabelAt(now) ??
                    switch ((appointment.status, timing)) {
                      (AppointmentStatus.requested, _) => 'Awaiting Confirmation',
                      (_, VisitTiming.early) => 'Get ready from ${DateFormat('h:mm a').format(appointment.opensAt)}',
                      _ => 'View appointment',
                    },
                style: AppTextStyles.buttonLabel.copyWith(color: AppColors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.white),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.bodyMuted.copyWith(color: AppColors.white),
          ),
        ),
      ],
    );
  }
}
