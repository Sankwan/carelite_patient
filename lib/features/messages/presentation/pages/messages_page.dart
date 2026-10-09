import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Messaging, which this backend does not have.
///
/// Deliberately NOT a "coming in Phase N" screen: there is no messages app,
/// no model, no endpoint and no signalling anywhere in
/// github.com/campofo/carelite — nothing to schedule against. Naming a phase
/// would imply the work is planned and sized when it has not been specified
/// at all. The honest version says what is true and points the patient at
/// the thing that does work.
///
/// The tab is kept rather than removed because removing it is a product
/// decision (the design has five tabs), and an empty slot in the nav bar
/// would be more confusing than a screen that explains itself.
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Messages', style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: AppColors.muted,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Messaging isn’t available yet',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'CareLite cannot send messages to clinicians yet. To reach '
                  'a clinician, book a consultation — your notes, '
                  'prescriptions and results all appear under Records.',
                  style: AppTextStyles.bodyMuted,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
