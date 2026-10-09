import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Poppins for headlines, Inter for body — matches the Figma type ramp.
/// Make sure both font families are added under pubspec.yaml `fonts:`
/// once the .ttf files are added to assets/fonts/.
abstract final class AppTextStyles {
  static const String _headlineFont = 'Poppins';
  static const String _bodyFont = 'Inter';

  static const TextStyle h1 = TextStyle(
    fontFamily: _headlineFont,
    fontWeight: FontWeight.w700,
    fontSize: 21,
    color: AppColors.ink,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _headlineFont,
    fontWeight: FontWeight.w700,
    fontSize: 17,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _bodyFont,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    color: AppColors.ink,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: _bodyFont,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    color: AppColors.muted,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: _bodyFont,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: AppColors.white,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _bodyFont,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    color: AppColors.muted,
  );
}
