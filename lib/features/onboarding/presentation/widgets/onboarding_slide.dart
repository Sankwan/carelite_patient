import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// One onboarding page: illustration, headline, supporting copy.
///
/// [illustration] is an icon rather than the Figma artwork — the real
/// illustrations have not been exported from the design file yet, so this
/// renders a branded stand-in instead of shipping a broken asset path.
class OnboardingSlide extends StatelessWidget {
  const OnboardingSlide({
    required this.illustration,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData illustration;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Decorative: the headline below carries the meaning.
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lightBlueTint,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            child: Icon(illustration, size: 88, color: AppColors.blue),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(title, style: AppTextStyles.h1, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Text(body, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
