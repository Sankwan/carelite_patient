/// 4px-based spacing scale used throughout the app. Keep paddings/margins
/// expressed in these constants rather than magic numbers so a future
/// density change is a one-line edit.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 14;
  static const double radiusXl = 20;

  /// The minimum tappable height/width for any interactive control
  /// (Apple HIG / Material both land on 44-48dp). Use this instead of a
  /// literal so every button stays in sync — see design critique, Oct 2026,
  /// on three 40px targets that drifted from the rest of the app.
  static const double touchTarget = 48;
}
