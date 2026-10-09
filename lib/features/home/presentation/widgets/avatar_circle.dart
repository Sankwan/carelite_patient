import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/initials.dart';

/// Monogram avatar. Initials are always derived from [name] — never passed
/// in separately — so the letters cannot drift from the name beside them.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    required this.name,
    this.size = 48,
    this.background = AppColors.teal,
    this.showAvailabilityDot = false,
    this.isAvailable = false,
    super.key,
  });

  final String name;
  final double size;
  final Color background;
  final bool showAvailabilityDot;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Text(
              initialsOf(name),
              style: AppTextStyles.h2.copyWith(
                color: AppColors.white,
                fontSize: size * 0.34,
              ),
            ),
          ),
          if (showAvailabilityDot)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.26,
                height: size * 0.26,
                decoration: BoxDecoration(
                  color: isAvailable ? AppColors.success : AppColors.muted,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
