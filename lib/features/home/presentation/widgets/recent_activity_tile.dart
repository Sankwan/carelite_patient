import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/appointment.dart';
import 'avatar_circle.dart';

/// One completed consultation in Recent Activity.
///
/// The Figma file names this section on an earlier wireframe but never draws
/// it, so the content is defined here: the patient's last completed
/// appointments, with a route into the notes the clinician left (agreed,
/// Sep 2026). Lab results and prescriptions join it once those tables exist.
class RecentActivityTile extends StatelessWidget {
  const RecentActivityTile({
    required this.appointment,
    required this.onViewNotes,
    super.key,
  });

  final Appointment appointment;
  final VoidCallback onViewNotes;

  @override
  Widget build(BuildContext context) {
    final hasNotes = (appointment.notes ?? '').trim().isNotEmpty;

    return InkWell(
      onTap: onViewNotes,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: [
            AvatarCircle(
              name: appointment.provider.displayName,
              size: 40,
              background: AppColors.lightBlueTint,
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
                  const SizedBox(height: 2),
                  Text(
                    appointment.relativeLabel(),
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
              ),
            ),
            Text(
              hasNotes ? 'View notes' : 'View',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
