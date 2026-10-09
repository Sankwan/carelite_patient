import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../domain/consultation.dart';
import '../../domain/investigation.dart';
import '../../domain/medical_record.dart';
import '../bloc/records_bloc.dart';
import '../bloc/records_event.dart';
import '../bloc/records_state.dart';
import '../widgets/facility_card.dart';
import '../widgets/record_section.dart';

/// Everything one consultation holds.
///
/// Takes the [Consultation] rather than an id so the header can render
/// immediately from data the list already has, while the four
/// consultation-scoped calls are still in flight.
class RecordDetailPage extends StatelessWidget {
  const RecordDetailPage({required this.consultation, super.key});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecordDetailBloc>(
      create: (_) => getIt<RecordDetailBloc>(param1: consultation)
        ..add(RecordOpened(consultation)),
      child: const RecordDetailView(),
    );
  }
}

/// The page body without its own `BlocProvider`, so tests can inject a Bloc.
class RecordDetailView extends StatelessWidget {
  const RecordDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Record', style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: BlocConsumer<RecordDetailBloc, RecordDetailState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) =>
              AppToast.error(context, state.failure!.message),
          builder: (context, state) {
            if (state.status == RecordDetailStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            final record = state.record;
            if (record == null) {
              return _Failed(state: state);
            }
            return RefreshIndicator(
              onRefresh: () async => context
                  .read<RecordDetailBloc>()
                  .add(const RecordsRefreshed()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _Header(consultation: state.consultation),
                  const SizedBox(height: AppSpacing.md),
                  _Summary(record: record),
                  const SizedBox(height: AppSpacing.md),
                  _Note(record: record),
                  const SizedBox(height: AppSpacing.md),
                  _Prescriptions(record: record),
                  const SizedBox(height: AppSpacing.md),
                  _Investigations(record: record),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
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
          Text(consultation.dateLabel, style: AppTextStyles.bodyMuted),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Consultation with ${consultation.clinicianLabel}',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            consultation.status.label,
            style: AppTextStyles.caption.copyWith(
              color: consultation.status == ConsultationStatus.closed
                  ? AppColors.muted
                  : AppColors.teal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.record});

  final MedicalRecord record;

  @override
  Widget build(BuildContext context) {
    final summary = record.summary;
    return RecordSection(
      title: 'Discharge summary',
      icon: Icons.assignment_turned_in_outlined,
      // Null is not a failure: the summary is generated when the appointment
      // is completed, so an open consultation legitimately has none.
      emptyMessage: record.consultation.status == ConsultationStatus.closed
          ? 'No summary was written for this consultation.'
          : 'A summary is written when the consultation is completed.',
      children: [
        if (summary != null && !summary.isEmpty) ...[
          if (summary.diagnosis.trim().isNotEmpty)
            RecordField(label: 'Diagnosis', value: summary.diagnosis),
          if (summary.advice.trim().isNotEmpty)
            RecordField(label: 'Advice', value: summary.advice),
          if (summary.prescriptions.trim().isNotEmpty)
            RecordField(label: 'Medication', value: summary.prescriptions),
          if (summary.followUpLabel != null)
            RecordField(label: 'Follow up', value: summary.followUpLabel!),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.record});

  final MedicalRecord record;

  @override
  Widget build(BuildContext context) {
    final note = record.note;
    return RecordSection(
      title: 'Clinical notes',
      icon: Icons.edit_note,
      emptyMessage: 'Your clinician did not record notes for this visit.',
      children: [
        if (note != null)
          for (final entry in note.sections.entries)
            RecordField(label: entry.key, value: entry.value),
      ],
    );
  }
}

class _Prescriptions extends StatelessWidget {
  const _Prescriptions({required this.record});

  final MedicalRecord record;

  @override
  Widget build(BuildContext context) {
    return RecordSection(
      title: 'Prescriptions',
      icon: Icons.medication_outlined,
      emptyMessage: 'No medication was prescribed at this visit.',
      children: [
        for (final prescription in record.prescriptions) ...[
          for (final item in prescription.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.drugName,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (item.instructions.isNotEmpty)
                    Text(item.instructions, style: AppTextStyles.bodyMuted),
                  if (item.notes.trim().isNotEmpty)
                    Text(item.notes, style: AppTextStyles.caption),
                ],
              ),
            ),
          if (prescription.prescriberName.trim().isNotEmpty)
            Text(
              'Prescribed by ${prescription.prescriberName}',
              style: AppTextStyles.caption,
            ),
          if (prescription.pharmacy != null)
            FacilityCard(
              heading: 'Collect from',
              facility: prescription.pharmacy!,
            ),
        ],
      ],
    );
  }
}

class _Investigations extends StatelessWidget {
  const _Investigations({required this.record});

  final MedicalRecord record;

  @override
  Widget build(BuildContext context) {
    return RecordSection(
      title: 'Tests & results',
      icon: Icons.science_outlined,
      emptyMessage: 'No tests were ordered at this visit.',
      children: [
        for (final investigation in record.investigations)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        investigation.testName,
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      investigation.status.label,
                      style: AppTextStyles.caption.copyWith(
                        color: investigation.status ==
                                InvestigationStatus.resultUploaded
                            ? AppColors.success
                            : AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (investigation.reason.trim().isNotEmpty)
                  Text(investigation.reason, style: AppTextStyles.bodyMuted),
                if (investigation.facility != null)
                  FacilityCard(
                    heading: investigation.isImaging ? 'Scan at' : 'Test at',
                    facility: investigation.facility!,
                  ),
                if (investigation.resultText != null &&
                    investigation.resultText!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrayBg,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      investigation.resultText!,
                      style: AppTextStyles.body,
                    ),
                  ),
                ],
                if (investigation.hasResultFile)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      // Said plainly: the file lives behind Django's MEDIA_URL
                      // and needs an authenticated download this app does not
                      // do yet. A tappable link that failed would be worse.
                      'A result file was attached. Ask your clinician for a '
                      'copy — CareLite cannot open attachments yet.',
                      style: AppTextStyles.caption,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.state});

  final RecordDetailState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.muted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not open this record',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.failure?.message ?? 'Please try again.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => context
                  .read<RecordDetailBloc>()
                  .add(RecordOpened(state.consultation)),
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
        ),
      ),
    );
  }
}
