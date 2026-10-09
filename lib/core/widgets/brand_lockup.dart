import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';

/// The left-aligned pin + wordmark used across every auth screen
/// (Login, OTP, Create Account, Biometrics).
///
/// Extracted because the Figma auth screens all share this exact lockup —
/// the design file centers it only on Biometrics, which is a file bug, not
/// a style choice. One widget means it can never drift again.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Decorative: no semanticLabel, because the adjacent wordmark
        // already carries the brand name and announcing the pin as well
        // would just duplicate it for screen readers.
        const Icon(Icons.location_on, color: AppColors.teal, size: 28),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CARE LITE HEALTH', style: AppTextStyles.caption.copyWith(
              color: AppColors.ink,
              fontSize: 12,
              letterSpacing: 0.5,
            )),
            Text('Care Beyond Distance', style: AppTextStyles.caption.copyWith(
              color: AppColors.tealText,
              fontWeight: FontWeight.w400,
            )),
          ],
        ),
      ],
    );
  }
}
