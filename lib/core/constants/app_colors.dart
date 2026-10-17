import 'package:flutter/material.dart';

/// CareLite design tokens, lifted directly from the Figma design system so
/// the app and the design file never drift apart. Do not invent new colors
/// here without updating Figma first.
abstract final class AppColors {
  static const Color ink = Color(0xFF0A1B35);
  static const Color teal = Color(0xFF1A9EB0);
  static const Color blue = Color(0xFF1247B0);
  static const Color muted = Color(0xFF5B6B85);
  static const Color border = Color(0xFFE4EAF2);
  static const Color white = Color(0xFFFFFFFF);
  static const Color navy = Color(0xFF1B3B8C);
  static const Color lightGrayBg = Color(0xFFF1F5FA);
  static const Color success = Color(0xFF18A06A);
  static const Color successBg = Color(0xFFDFF5E8);
  static const Color error = Color(0xFFE23D5B);
  static const Color lightTealTint = Color(0xFFE3F7F9);
  static const Color lightBlueTint = Color(0xFFE5EDFB);
  static const Color gold = Color(0xFFF2A516);
  static const Color goldBg = Color(0xFFFDF1DC);
  static const Color goldText = Color(0xFFB5760A);

  /// Text-safe accent: the brand teal (#1A9EB0) measures ~3.2:1 against
  /// white and fails WCAG AA for normal text. Use this darker variant for
  /// small text and links; reserve [teal] for large filled elements/icons.
  /// See design critique, Aug 2026.
  static const Color tealText = Color(0xFF0E7A89);

  /// White at 70% opacity — secondary text on a dark surface (the Call
  /// screen's ink background). Not in the Figma token set, which has no
  /// dark-surface screen; added for this one case rather than picking an
  /// arbitrary gray that would drift from the rest of the palette.
  static const Color white70 = Color(0xB3FFFFFF);

  /// NEW — not yet in Figma. Card surface for the scoped dark-mode treatment
  /// (vitals/dashboard only — see docs/ui_research/phase3_design_system.md
  /// §5). [ink] doubles as the dark scaffold background since it's already
  /// the darkest token in the palette; this is its lighter "card on
  /// scaffold" counterpart, matching the [white] on [lightGrayBg]
  /// relationship in light mode.
  static const Color cardDark = Color(0xFF132A4D);
}
