import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Single-select chip row used for both Gender and Blood Type.
///
/// Selection is teal for every group. The Figma file renders the selected
/// blood-type chip in the error red, which reads as a validation failure
/// rather than a choice and would need its own contrast check — teal keeps
/// one selection language across the form (agreed, Sep 2026).
class ChoiceChipGroup<T> extends StatelessWidget {
  const ChoiceChipGroup({
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: values.map((value) {
        final isSelected = value == selected;
        return ChoiceChip(
          label: Text(
            labelOf(value),
            style: AppTextStyles.body.copyWith(
              color: isSelected ? AppColors.white : AppColors.ink,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => onSelected(value),
          showCheckmark: false,
          backgroundColor: AppColors.white,
          selectedColor: AppColors.teal,
          // 48dp min height keeps every chip a legal touch target.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            side: BorderSide(
              color: isSelected ? AppColors.teal : AppColors.border,
            ),
          ),
        );
      }).toList(),
    );
  }
}
