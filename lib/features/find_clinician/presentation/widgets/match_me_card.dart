import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// "Match me with any available clinician".
///
/// This is the whole of this backend's dispatch feature: `booking_type: ANY`
/// with `mode: ON_DEMAND` asks the server to pick the highest-rated verified
/// clinician who is online right now and return the appointment already
/// assigned. It is one synchronous request — there is no searching state, no
/// list of notified candidates, and nothing to cancel, so the copy promises
/// a match rather than a search.
class MatchMeCard extends StatelessWidget {
  const MatchMeCard({required this.onPressed, this.isBusy = false, super.key});

  final VoidCallback onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.lightTealTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt, color: AppColors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Need someone now?',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                const Text(
                  'We’ll match you with the highest-rated clinician '
                  'who is online.',
                  style: AppTextStyles.bodyMuted,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isBusy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              onPressed: onPressed,
              tooltip: 'Match me with any available clinician',
              icon: const Icon(Icons.arrow_forward, color: AppColors.white),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.teal,
                minimumSize: const Size(48, 48),
                shape: const CircleBorder(),
              ),
            ),
        ],
      ),
    );
  }
}
