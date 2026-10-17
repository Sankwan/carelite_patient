import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';

/// The app's primary call-to-action, lifted verbatim from the pattern in
/// `login_page.dart` so every async action in the app disables its trigger
/// and shows the same inline spinner while in flight.
///
/// [onPressed] is nullable on purpose: passing `null` disables the button
/// for reasons other than loading (e.g. an invalid form).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        // Navy, not teal: teal is the app's accent color (nav selection,
        // links, icons) everywhere else, so a teal button couldn't be told
        // apart from an informational accent. Navy is reserved for "do
        // this" — see docs/ui_research/phase3_design_system.md §2.
        backgroundColor: AppColors.navy,
        disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        // Touch-target floor regardless of label length.
        minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
            )
          : Text(label, style: AppTextStyles.buttonLabel),
    );
  }
}
