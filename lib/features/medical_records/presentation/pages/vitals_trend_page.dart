import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
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
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Vitals trend', style: AppTextStyles.h1),
      ),
      body: SafeArea(
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
                    const _EmptyState()
                  else
                    for (final record in records) ...[
                      _VitalsCard(record: record),
                      const SizedBox(height: AppSpacing.md),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.record});

  final VitalsRecord record;

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
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
                  color: AppColors.lightTealTint,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.monitor_heart_outlined, color: AppColors.teal),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  record.dateLabel,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
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
                      Text(reading.label, style: AppTextStyles.caption),
                      Text(reading.value, style: AppTextStyles.body),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(Icons.monitor_heart_outlined, size: 48, color: AppColors.muted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No vitals recorded yet',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Your clinician records these during a consultation.',
            style: AppTextStyles.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
