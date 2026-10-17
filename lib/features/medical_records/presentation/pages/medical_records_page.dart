import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/security/record_lock_gate.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../domain/consultation.dart';
import '../bloc/records_bloc.dart';
import '../bloc/records_event.dart';
import '../bloc/records_state.dart';
import 'record_detail_page.dart';
import 'vitals_trend_page.dart';

/// The patient's consultation history.
///
/// The list shows consultations only. Prescriptions, investigations, notes
/// and summaries are all consultation-scoped on this backend, so fetching
/// them per row would be four requests per record — they load when a record
/// is opened instead. See docs/PROJECT_STATUS.md.
class MedicalRecordsPage extends StatelessWidget {
  const MedicalRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Medical Records', style: AppTextStyles.h1),
      ),
      body: RecordLockGate(
          child: SafeArea(
        child: BlocConsumer<RecordsBloc, RecordsState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) =>
              AppToast.error(context, state.failure!.message),
          builder: (context, state) {
            if (state.status == RecordsStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  context.read<RecordsBloc>().add(const RecordsRefreshed()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const _VitalsTrendLink(),
                  const SizedBox(height: AppSpacing.md),
                  if (state.consultations.isEmpty)
                    _EmptyState(state: state)
                  else
                    for (final consultation in state.consultations) ...[
                      _ConsultationTile(consultation: consultation),
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

class _VitalsTrendLink extends StatelessWidget {
  const _VitalsTrendLink();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute<void>(builder: (_) => const VitalsTrendPage()),
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lightTealTint,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.monitor_heart_outlined,
                    color: AppColors.teal),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Vitals trend',
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsultationTile extends StatelessWidget {
  const _ConsultationTile({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    final closed = consultation.status == ConsultationStatus.closed;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => RecordDetailPage(consultation: consultation),
          ),
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lightTealTint,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                // One folder per consultation: everything from booking to
                // the clinician's summary lives inside it.
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      consultation.clinicianLabel,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${consultation.dateLabel} · Notes, results, prescriptions',
                      style: AppTextStyles.bodyMuted,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!closed) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        consultation.status.label,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});

  final RecordsState state;

  @override
  Widget build(BuildContext context) {
    final failed = state.failure != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(
            failed ? Icons.cloud_off : Icons.folder_open,
            size: 48,
            color: AppColors.muted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            failed ? 'Could not load your records' : 'No records yet',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            failed
                ? state.failure!.message
                : 'After a consultation, your notes, prescriptions and test '
                    'results appear here.',
            style: AppTextStyles.bodyMuted,
            textAlign: TextAlign.center,
          ),
          if (failed) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () =>
                  context.read<RecordsBloc>().add(const RecordsRefreshed()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: AppColors.teal),
              ),
              child: Text(
                'Try again',
                style: AppTextStyles.body.copyWith(color: AppColors.tealText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
