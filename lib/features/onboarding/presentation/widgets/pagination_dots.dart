import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

/// Slide position indicator. Purely decorative — the parent exposes the
/// real position to assistive tech via a `Semantics` label, so these dots
/// are hidden from the accessibility tree rather than read out as three
/// meaningless shapes.
class PaginationDots extends StatelessWidget {
  const PaginationDots({
    required this.count,
    required this.activeIndex,
    super.key,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = index == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            height: 8,
            width: isActive ? 20 : 8,
            decoration: BoxDecoration(
              color: isActive ? AppColors.teal : AppColors.border,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          );
        }),
      ),
    );
  }
}
