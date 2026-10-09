import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Search entry point plus the filter button.
///
/// Not a live text field: tapping either control opens Find Clinician, which
/// owns the real search and filter chips (Phase 3). A field that accepts
/// typing but does nothing would be worse than one that clearly navigates.
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    required this.onSearchPressed,
    required this.onFilterPressed,
    super.key,
  });

  final VoidCallback onSearchPressed;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onSearchPressed,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Semantics(
              button: true,
              label: 'Search doctors and specialists',
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.lightGrayBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppColors.muted),
                    SizedBox(width: AppSpacing.sm),
                    Text('Search doctors, specialists...',
                        style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        IconButton(
          onPressed: onFilterPressed,
          tooltip: 'Filter results',
          icon: const Icon(Icons.tune, color: AppColors.white),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.blue,
            minimumSize: const Size(52, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
        ),
      ],
    );
  }
}
