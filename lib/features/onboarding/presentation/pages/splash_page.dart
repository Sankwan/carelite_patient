import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';

/// Brand splash, built from Figma node 152:530 — a white ground with the
/// centered logo lockup, not the navy/teal field an earlier draft of the
/// spec described (the design file was updated after that was written).
///
/// It holds for [_minimumDisplay] so the brand mark is actually legible
/// rather than flashing past, then hands off to the router: this screen
/// never decides *where* the user goes, it only decides *when* to leave.
/// [buildAppRouter]'s redirect owns the destination.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static const Duration _minimumDisplay = Duration(milliseconds: 1200);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashPage._minimumDisplay, _leaveSplash);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _leaveSplash() {
    if (!mounted) return;
    // Any in-funnel route works as the hand-off target; `redirect` will
    // immediately re-point it at onboarding / profile / home as needed.
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stand-in for the Figma logo mark, which has not been exported
            // from the design file yet. Decorative — the wordmark below is
            // what assistive tech should read.
            const Icon(Icons.local_hospital_rounded, size: 96, color: AppColors.navy),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'CARE LITE HEALTH',
              style: AppTextStyles.h1.copyWith(
                color: AppColors.navy,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'CARE BEYOND DISTANCE',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.teal,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
