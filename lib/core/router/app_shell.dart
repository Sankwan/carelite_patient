import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.calendar_today_outlined, label: 'Appts'),
    (icon: Icons.chat_bubble_outline, label: 'Messages'),
    (icon: Icons.description_outlined, label: 'Records'),
    (icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
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
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon, color: AppColors.muted),
              selectedIcon: Icon(tab.icon, color: AppColors.blue),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

/// Shared label styling for the nav bar, kept next to the shell so the tab
/// chrome reads from one place.
TextStyle navigationLabelStyle({required bool selected}) {
  return AppTextStyles.caption.copyWith(
    color: selected ? AppColors.blue : AppColors.muted,
    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
  );
}
