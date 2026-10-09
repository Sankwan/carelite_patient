import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/location_repository.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';

/// Figma node 292:51, with both copy bugs from that frame corrected: the
/// brand name read "Car Lite Health", and the disclaimer was ungrammatical
/// ("Note that without setting up the location, we cant help you as much").
class EnableLocationPage extends StatelessWidget {
  const EnableLocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: BlocConsumer<LocationBloc, LocationState>(
          listenWhen: (previous, current) =>
              previous.status != current.status ||
              previous.failure != current.failure,
          listener: (context, state) {
            if (state.failure != null) {
              AppToast.error(context, state.failure!.message);
            }
            if (state.isResolved) {
              context.go(AppRoutes.home);
            }
          },
          builder: (context, state) {
            final isPermanentlyDenied =
                state.access == LocationAccess.deniedForever;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Decorative — the headline immediately below says it.
                  const Icon(Icons.location_on, size: 96, color: AppColors.teal),
                  const SizedBox(height: AppSpacing.xxl),
                  const Text(
                    'Enable Location Access',
                    style: AppTextStyles.h1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'CareLite Health uses your location to show clinicians, '
                    'labs and pharmacies near you to provide accurate '
                    'services to you.',
                    style: AppTextStyles.bodyMuted,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (isPermanentlyDenied)
                    _PermanentlyDeniedActions(
                      onOpenSettings: () => context
                          .read<LocationBloc>()
                          .add(const LocationSettingsOpened()),
                      onContinue: () => context.go(AppRoutes.home),
                    )
                  else ...[
                    PrimaryButton(
                      label: 'Allow Location Access',
                      isLoading: state.status == LocationStatus.requesting,
                      onPressed: () => context
                          .read<LocationBloc>()
                          .add(const LocationPermissionRequested()),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () => context
                          .read<LocationBloc>()
                          .add(const LocationSkipped()),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        'Maybe Later',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'You can still browse the app without location access, '
                    "but we won't be able to show clinicians, labs, or "
                    'pharmacies near you.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Once the OS reports a permanent denial the in-app prompt can never
/// appear again, so the only honest options are the settings app or
/// continuing without nearby results — never a dead end.
class _PermanentlyDeniedActions extends StatelessWidget {
  const _PermanentlyDeniedActions({
    required this.onOpenSettings,
    required this.onContinue,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Location access is turned off for CareLite. You can enable it in '
          'your device settings.',
          style: AppTextStyles.bodyMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(label: 'Open Settings', onPressed: onOpenSettings),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: onContinue,
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(
            'Continue without location',
            style: AppTextStyles.body.copyWith(
              color: AppColors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
