import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import 'avatar_circle.dart';

/// Greeting row: avatar, "Good morning, Esi", location, notification bell.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.greeting,
    required this.name,
    required this.onNotificationsPressed,
    this.avatarLabel,
    this.locationLabel,
    this.hasUnreadNotifications = false,
    super.key,
  });

  final String greeting;
  final String? name;
  final VoidCallback onNotificationsPressed;

  /// What the avatar's initials are derived from. Deliberately separate
  /// from [name]: this backend has no name field at all, so [name] is null
  /// for every patient and the greeting stays a plain "Good morning" — but
  /// the avatar still needs *something* better than '?' for a signed-in
  /// account, and falls back to the formatted username (see
  /// `HomeState.avatarLabel`). Falls back to [name] itself if ever set, so a
  /// caller with a real name doesn't need to pass both.
  final String? avatarLabel;

  final String? locationLabel;
  final bool hasUnreadNotifications;

  @override
  Widget build(BuildContext context) {
    final displayName = name;
    return Row(
      children: [
        AvatarCircle(
          name: avatarLabel ?? displayName ?? '?',
          background: AppColors.success,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName == null ? greeting : '$greeting, $displayName',
                style: AppTextStyles.h2,
                overflow: TextOverflow.ellipsis,
              ),
              if (locationLabel != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.tealText),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        locationLabel!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.tealText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Icon-only, so it carries its own label for screen readers.
        IconButton(
          onPressed: onNotificationsPressed,
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: hasUnreadNotifications,
            backgroundColor: AppColors.error,
            child: const Icon(Icons.notifications_none_rounded, color: AppColors.ink),
          ),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.lightGrayBg,
            minimumSize: const Size(48, 48),
          ),
        ),
      ],
    );
  }
}
