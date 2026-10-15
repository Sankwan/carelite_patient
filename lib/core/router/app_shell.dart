import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/messages/presentation/bloc/messages_badge_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// The five-tab chrome around the authenticated app.
///
/// One `StatefulShellRoute` for all five tabs, rather than the two different
/// nav structures the Figma frames use across screens. Each branch keeps its
/// own navigator, so a tab's scroll position and page stack survive switching
/// away and back.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const int _messagesTab = 2;

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.calendar_today_outlined, label: 'Appts'),
    (icon: Icons.chat_bubble_outline, label: 'Messages'),
    (icon: Icons.description_outlined, label: 'Records'),
    (icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadMessages = context.watch<MessagesBadgeBloc?>()?.state ?? 0;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.lightBlueTint,
        // Labels stay visible on every tab: five icon-only destinations are
        // hard to tell apart, and the labels are the accessible name.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the current tab again pops it back to its root, which is
          // the behaviour users expect from a bottom nav.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (final (index, tab) in _tabs.indexed)
            NavigationDestination(
              icon: _badged(
                Icon(tab.icon, color: AppColors.muted),
                index == _messagesTab ? unreadMessages : 0,
              ),
              selectedIcon: _badged(
                Icon(tab.icon, color: AppColors.blue),
                index == _messagesTab ? unreadMessages : 0,
              ),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

Widget _badged(Widget icon, int count) {
  if (count <= 0) return icon;
  return Badge(
    label: Text(count > 99 ? '99+' : '$count'),
    backgroundColor: AppColors.error,
    child: icon,
  );
}

/// Shared label styling for the nav bar, kept next to the shell so the tab
/// chrome reads from one place.
TextStyle navigationLabelStyle({required bool selected}) {
  return AppTextStyles.caption.copyWith(
    color: selected ? AppColors.blue : AppColors.muted,
    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
  );
}
