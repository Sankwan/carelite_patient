import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// One titled block on a record.
///
/// Renders even when it has nothing, via [emptyMessage] — a section that
/// silently disappears leaves the patient unable to tell "no prescription
/// was issued" from "the prescriptions failed to load".
class RecordSection extends StatelessWidget {
  const RecordSection({
    required this.title,
    required this.icon,
    this.children = const [],
    this.emptyMessage,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.teal),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (children.isEmpty)
            Text(
              emptyMessage ?? 'Nothing recorded.',
              style: AppTextStyles.bodyMuted,
            )
          else
            ...children,
        ],
      ),
    );
  }
}

/// A heading/value pair inside a section.
class RecordField extends StatelessWidget {
  const RecordField({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
