import 'package:flutter/material.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/external_launcher.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../domain/care_facility.dart';

/// Where the patient has to go, with a way to get there and a way to call.
///
/// Each button appears only when the server sent what it needs: no
/// coordinates, no Directions; no phone, no Call.
class FacilityCard extends StatelessWidget {
  const FacilityCard({
    required this.heading,
    required this.facility,
    super.key,
  });

  /// "Collect from" for a pharmacy, "Test at" for a lab.
  final String heading;
  final CareFacility facility;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightGrayBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(
            facility.name,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          if (facility.address != null)
            Text(facility.address!, style: AppTextStyles.bodyMuted),
          if (facility.operatingHours != null)
            Text(facility.operatingHours!, style: AppTextStyles.caption),
          if (facility.hasLocation || facility.hasPhone) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (facility.hasLocation)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openDirections(context),
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                if (facility.hasLocation && facility.hasPhone)
                  const SizedBox(width: AppSpacing.sm),
                if (facility.hasPhone)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _call(context),
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openDirections(BuildContext context) async {
    final opened = await getIt<ExternalLauncher>().openDirections(
      latitude: facility.latitude!,
      longitude: facility.longitude!,
    );
    if (!opened && context.mounted) {
      AppToast.error(context, 'Could not open maps on this phone.');
    }
  }

  Future<void> _call(BuildContext context) async {
    final opened = await getIt<ExternalLauncher>().dial(facility.phone!);
    if (!opened && context.mounted) {
      // The number is shown so the patient can still dial it by hand.
      AppToast.error(context, 'Could not open the dialler. Call ${facility.phone}.');
    }
  }
}
