import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/provider.dart';
import 'avatar_circle.dart';
import 'rating_badge.dart';

/// One row in "Top clinicians" or "Nearby Diagnostic Labs & Pharmacies".
///
/// Every value on this card comes from the [Provider] record — name,
/// specialty, rating, fee, distance and the derived monogram — so the same
/// provider reads identically here, in the hero card, and on every later
/// screen.
class ProviderCard extends StatelessWidget {
  const ProviderCard({required this.provider, required this.onTap, super.key});

  final Provider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rating = provider.rating;
    final distance = provider.distanceLabel;
    final fee = provider.consultationFee;

    return InkWell(
      onTap: onTap,
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
              name: provider.displayName,
              background: provider.kind == ProviderKind.clinician
                  ? AppColors.teal
                  : AppColors.blue,
              showAvailabilityDot: true,
              isAvailable: provider.isAvailable,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.displayName,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rating != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        RatingBadge(rating: rating),
                      ],
                    ],
                  ),
                  if (provider.specialty != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      provider.specialty!,
                      style: AppTextStyles.bodyMuted,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      // Distance is omitted rather than faked when the
                      // patient has not shared their location.
                      if (distance != null) ...[
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.tealText),
                        const SizedBox(width: 2),
                        Text(distance, style: AppTextStyles.caption.copyWith(
                          color: AppColors.tealText,
                        )),
                      ],
                      if (distance != null && fee != null)
                        const SizedBox(width: AppSpacing.md),
                      if (fee != null)
                        Text(fee.formatted, style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
