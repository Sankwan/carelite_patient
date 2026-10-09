import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/search_filter.dart';

/// The availability toggle, plus specialty shortcuts when [specialties] is
/// non-empty.
///
/// Every chip here maps to a query parameter the backend has. There is no
/// "Nearest" or "Lowest fee" chip because neither can be built — see
/// [ClinicianFilter] for why they are absent rather than disabled.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    required this.filter,
    required this.onSpecialtySelected,
    required this.onAvailabilityToggled,
    this.specialties = const [],
    super.key,
  });

  final ClinicianFilter filter;
  final ValueChanged<String> onSpecialtySelected;
  final VoidCallback onAvailabilityToggled;
  final List<String> specialties;

  @override
  Widget build(BuildContext context) {
    final selected = filter.specialty.trim().toLowerCase();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _Chip(
            label: 'Available now',
            icon: Icons.bolt,
            selected: filter.onlineOnly,
            onTap: onAvailabilityToggled,
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final specialty in specialties) ...[
            _Chip(
              label: specialty,
              selected: selected == specialty.toLowerCase(),
              // Tapping the selected chip clears it, so a filter can always
              // be undone with the control that set it.
              onTap: () => onSpecialtySelected(
                selected == specialty.toLowerCase() ? '' : specialty,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          constraints: const BoxConstraints(minHeight: 40),
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.white : AppColors.muted,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? AppColors.white : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
