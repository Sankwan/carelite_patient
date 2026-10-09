import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// The gold "★ 4.9" pill. Takes the value from the provider record so a
/// rating can never differ between two places on the same screen.
class RatingBadge extends StatelessWidget {
  const RatingBadge({required this.rating, this.onDark = false, super.key});

  final double rating;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: onDark ? AppColors.white : AppColors.goldBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: AppTextStyles.caption.copyWith(color: AppColors.goldText),
          ),
        ],
      ),
    );
  }
}
