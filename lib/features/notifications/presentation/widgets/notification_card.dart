import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/app_notification.dart';

/// One notification.
///
/// The Figma card pairs a monogram avatar with "Ordered by Dr. Ama Owusu" —
/// neither is available here. A notification carries no person at all
/// (`title`, `body`, `type`, `payload`), so a monogram would be inventing a
/// name, which is exactly the class of bug the design itself has on this
/// screen (its avatar reads "DK" beside "Dr. Ama Owusu"). A per-type icon
/// says the same thing truthfully.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    required this.notification,
    required this.onTap,
    this.actionLabel,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  /// Null when this type has nowhere to go — the card still renders and is
  /// still tappable to mark it read, it just has no button promising a
  /// destination.
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(notification.type);
    final unread = notification.isUnread;

    return Semantics(
      label: unread ? 'Unread notification' : null,
      button: true,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: InkWell(
          // The whole card is the tap target, not just the button. Without
          // this, a PAYMENT or generic notification — the two types with no
          // destination and therefore no button — could never be marked read
          // at all, so it would sit unread forever and hold the Home bell's
          // badge on with nothing the patient could do about it.
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Ink(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(
                color:
                    unread ? accent.withValues(alpha: 0.35) : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconFor(notification.type),
                          color: accent, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: AppTextStyles.body.copyWith(
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                          if (notification.body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(notification.body,
                                style: AppTextStyles.bodyMuted),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              const Icon(Icons.schedule,
                                  size: 14, color: AppColors.muted),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                // Computed from created_at, never a fixed string.
                                notification.relativeLabel(),
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: AppSpacing.xs),
                        decoration: BoxDecoration(
                            color: accent, shape: BoxShape.circle),
                      ),
                  ],
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                      ),
                      child:
                          Text(actionLabel!, style: AppTextStyles.buttonLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(NotificationType type) => switch (type) {
        NotificationType.incomingCall => Icons.videocam_outlined,
        NotificationType.clinicianAssigned => Icons.person_outline,
        NotificationType.resultReady => Icons.science_outlined,
        NotificationType.payment => Icons.payments_outlined,
        NotificationType.generic => Icons.notifications_none_rounded,
      };

  static Color _accentFor(NotificationType type) => switch (type) {
        NotificationType.incomingCall => AppColors.error,
        NotificationType.clinicianAssigned => AppColors.teal,
        NotificationType.resultReady => AppColors.blue,
        NotificationType.payment => AppColors.goldText,
        NotificationType.generic => AppColors.muted,
      };
}
