import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';

/// The app's one toast surface — replaces every ad hoc
/// `ScaffoldMessenger.of(context).showSnackBar(...)` call.
///
/// `ToastificationStyle.flat` over the default `fillColored`: a solid-fill
/// toast reads as an alarm even for a routine "coming soon" notice, and this
/// app already carries its own colour system (AppColors) rather than
/// toastification's — flat keeps the message on a plain surface with just an
/// accent icon, so severity comes from the icon/colour, not a wash of colour
/// across the whole toast.
///
/// A toast over a SnackBar specifically because several call sites here sit
/// on screens with a bottom nav (the shell routes) or a bottom sheet-style
/// primary button hugging the bottom edge — a SnackBar competes with both for
/// the same strip of screen. A toast floats near the top instead.
abstract final class AppToast {
  static void error(BuildContext context, String message) {
    _show(
      context,
      message: message,
      type: ToastificationType.error,
      icon: Icons.error_outline,
      accent: AppColors.error,
    );
  }

  static void warning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      type: ToastificationType.warning,
      icon: Icons.warning_amber_rounded,
      accent: AppColors.goldText,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      type: ToastificationType.info,
      icon: Icons.info_outline,
      accent: AppColors.blue,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required ToastificationType type,
    required IconData icon,
    required Color accent,
  }) {
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flat,
      title: Text(message, style: AppTextStyles.body),
      icon: Icon(icon, color: accent),
      primaryColor: accent,
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 4),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      showProgressBar: false,
      dragToClose: true,
    );
  }
}
