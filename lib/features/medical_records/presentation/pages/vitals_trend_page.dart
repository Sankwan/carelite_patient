import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/security/record_lock_gate.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../domain/vitals_record.dart';
import '../bloc/vitals_bloc.dart';
import '../bloc/vitals_event.dart';
import '../bloc/vitals_state.dart';

/// Every vitals reading a clinician has recorded, newest first — read-only:
/// a patient cannot add one, only a clinician does during a consultation.
class VitalsTrendPage extends StatelessWidget {
  const VitalsTrendPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VitalsBloc>(
      create: (_) => getIt<VitalsBloc>()..add(const VitalsStarted()),
      child: const VitalsTrendView(),
    );
  }
}

class VitalsTrendView extends StatelessWidget {
  const VitalsTrendView({super.key});

  @override
  Widget build(BuildContext context) {
    // Scoped dark mode: numeric vitals data is exactly the case Phase 1
    // research found dark surfaces earning their keep (see
    // docs/ui_research/phase3_design_system.md §5) — the rest of the app
    // stays light until a later pass extends it deliberately, rather than
    // flipping with the system setting everywhere at once.
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final scaffoldColor = isDark ? AppColors.ink : AppColors.lightGrayBg;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: scaffoldColor,
        elevation: 0,
        // AppBar's default icon theme doesn't know about this page's local
        // isDark flag (there's no app-wide darkTheme to pick it up from —
        // see docs/ui_research/phase3_design_system.md §5), so the back
        // button needs to be told explicitly or it renders near-invisible
        // on the dark scaffold.
        iconTheme:
            IconThemeData(color: isDark ? AppColors.white : AppColors.ink),
        title: Text(
          'Vitals trend',
          style: AppTextStyles.h1.copyWith(
            color: isDark ? AppColors.white : AppColors.ink,
          ),
        ),
      ),
      body: RecordLockGate(
          child: SafeArea(
        child: BlocConsumer<VitalsBloc, VitalsState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) =>
              AppToast.error(context, state.failure!.message),
          builder: (context, state) {
            if (state.status == VitalsStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            final records =
                state.newestFirst.where((r) => r.hasAnyMeasurement).toList();
            return RefreshIndicator(
              onRefresh: () async =>
                  context.read<VitalsBloc>().add(const VitalsRefreshed()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (records.isEmpty)
                    _EmptyState(isDark: isDark)
                  else
                    for (final record in records) ...[
                      _VitalsCard(record: record, isDark: isDark),
                      const SizedBox(height: AppSpacing.md),
                    ],
                ],
              ),
            );
          },
        ),
      )),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.record, required this.isDark});

  final VitalsRecord record;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final readings = <({String label, String value})>[
      if (record.bloodPressureLabel != null)
        (label: 'Blood pressure', value: '${record.bloodPressureLabel} mmHg'),
      if (record.pulse != null) (label: 'Pulse', value: '${record.pulse} bpm'),
      if (record.temperature != null)
        (label: 'Temperature', value: '${record.temperature}°C'),
      if (record.respiratoryRate != null)
        (label: 'Respiratory rate', value: '${record.respiratoryRate}/min'),
      if (record.spo2 != null) (label: 'SpO2', value: '${record.spo2}%'),
      if (record.weightKg != null)
        (label: 'Weight', value: '${record.weightKg} kg'),
      if (record.heightCm != null)
        (label: 'Height', value: '${record.heightCm} cm'),
      if (record.bmi != null) (label: 'BMI', value: '${record.bmi}'),
      if (record.bloodGlucose != null)
        (label: 'Blood glucose', value: '${record.bloodGlucose} mmol/L'),
    ];

    final primaryTextColor = isDark ? AppColors.white : AppColors.ink;
    final mutedTextColor = isDark ? AppColors.white70 : AppColors.muted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.teal.withValues(alpha: 0.18)
                      : AppColors.lightTealTint,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.monitor_heart_outlined,
                    color: AppColors.teal),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  record.dateLabel,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              for (final reading in readings)
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reading.label,
                        style: AppTextStyles.caption
                            .copyWith(color: mutedTextColor),
                      ),
                      Text(
                        reading.value,
                        style: AppTextStyles.body
                            .copyWith(color: primaryTextColor),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mutedTextColor = isDark ? AppColors.white70 : AppColors.muted;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.monitor_heart_outlined, size: 48, color: mutedTextColor),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No vitals recorded yet',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.white : AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your clinician records these during a consultation.',
            style: AppTextStyles.bodyMuted.copyWith(color: mutedTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
