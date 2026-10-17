import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/security/record_lock.dart';
import '../../../../core/security/record_lock_gate.dart';
import '../../../../core/utils/external_launcher.dart';
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
      body: RecordLockGate(
          child: SafeArea(
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
                  const SizedBox(height: AppSpacing.md),
                  _Timeline(record: record),
                  const SizedBox(height: AppSpacing.md),
                  _SharedWith(record: record),
                ],
              ),
            );
          },
        ),
      )),
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
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _InvestigationEntry(
              investigation: investigation,
              clinician: record.consultation.clinicianLabel,
            ),
          ),
      ],
    );
  }
}

class _InvestigationEntry extends StatefulWidget {
  const _InvestigationEntry(
      {required this.investigation, required this.clinician});

  final Investigation investigation;
  final String clinician;

  @override
  State<_InvestigationEntry> createState() => _InvestigationEntryState();
}

class _InvestigationEntryState extends State<_InvestigationEntry> {
  /// A sensitive result stays covered until the patient confirms it's them,
  /// every time the screen is opened — whether or not the record lock is on.
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final investigation = widget.investigation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                investigation.testName,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              investigation.status.label,
              style: AppTextStyles.caption.copyWith(
                color:
                    investigation.status == InvestigationStatus.resultUploaded
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
        if (investigation.hasResult) ...[
          const SizedBox(height: AppSpacing.sm),
          ..._result(context, investigation),
        ],
      ],
    );
  }

  List<Widget> _result(BuildContext context, Investigation investigation) {
    switch (investigation.release) {
      case ResultRelease.pendingReview:
        return [
          _Notice(
            icon: Icons.hourglass_top_rounded,
            text:
                'Your result is with ${widget.clinician}. You’ll see it here once they’ve '
                'reviewed it, or within 48 hours.',
          ),
        ];
      case ResultRelease.heldForClinician:
        return [
          _Notice(
            icon: Icons.forum_outlined,
            text:
                'Your result is ready. ${widget.clinician} will go through it with you.',
          ),
        ];
      case ResultRelease.released:
        break;
    }
    if (investigation.isSensitive && !_revealed) {
      return [
        _Notice(
          icon: Icons.lock_outline_rounded,
          text: 'This result is private. Confirm it’s you to view it.',
          action: TextButton(
            onPressed: () async {
              final ok = await getIt<RecordLock>()
                  .authenticate('View your private result');
              if (ok && mounted) setState(() => _revealed = true);
            },
            child: const Text('View result'),
          ),
        ),
      ];
    }
    return [
      if (investigation.values.isNotEmpty)
        _ValuesTable(values: investigation.values),
      if (investigation.resultText != null &&
          investigation.resultText!.trim().isNotEmpty) ...[
        if (investigation.values.isNotEmpty)
          const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.lightGrayBg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Text(investigation.resultText!, style: AppTextStyles.body),
        ),
      ],
      for (final attachment in investigation.attachments)
        _AttachmentRow(attachment: attachment),
      if (investigation.hasResultFile && investigation.attachments.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            // The file sits behind a /media/ path the server doesn't serve
            // yet (R3). A link that failed would be worse than saying so.
            'The lab attached its report. It will open here once CareLite can '
            'show attachments; until then, ask your clinician for a copy.',
            style: AppTextStyles.caption,
          ),
        ),
    ];
  }
}

class _ValuesTable extends StatelessWidget {
  const _ValuesTable({required this.values});

  final List<ResultValue> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGrayBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (final (index, value) in values.indexed) ...[
            if (index > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value.name, style: AppTextStyles.body),
                        if (value.referenceRange.isNotEmpty)
                          Text('Normal ${value.referenceRange}',
                              style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        value.unit.isEmpty
                            ? value.value
                            : '${value.value} ${value.unit}',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: value.flag.isAbnormal
                              ? AppColors.error
                              : AppColors.ink,
                        ),
                      ),
                      if (value.flag.isAbnormal)
                        Text(
                          value.flag.label,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.error),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment});

  final ResultAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Material(
        color: AppColors.lightGrayBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: () async {
            final opened =
                await getIt<ExternalLauncher>().openDocument(attachment.url);
            if (!opened && context.mounted) {
              AppToast.error(
                  context, 'Couldn’t open the attachment. Try again.');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  attachment.isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: AppColors.tealText,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: Text(attachment.name, style: AppTextStyles.body)),
                const Icon(Icons.open_in_new_rounded,
                    size: 18, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightTealTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.tealText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.body)),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// What happened in this consultation, in order — built from the dates the
/// record already carries. The full server-side timeline (calls, every
/// note version, each lab step) arrives with the episode endpoint.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.record});

  final MedicalRecord record;

  @override
  Widget build(BuildContext context) {
    final events = <({DateTime at, String label})>[
      if (record.consultation.startedAt case final at?)
        (at: at, label: 'Consultation started'),
      if (record.note?.createdAt case final at?)
        (
          at: at,
          label: 'Clinical notes written (version ${record.note!.version})'
        ),
      for (final rx in record.prescriptions)
        if (rx.signedAt case final at?)
          (at: at, label: 'Prescription signed by ${rx.prescriberName}'),
      for (final inv in record.investigations)
        if (inv.resultUploadedAt case final at?)
          (
            at: at,
            label:
                '${inv.testName} result from ${inv.facility?.name ?? 'the lab'}'
          ),
      if (record.consultation.endedAt case final at?)
        (at: at, label: 'Consultation completed'),
      if (record.summary?.generatedAt case final at?)
        (at: at, label: 'Discharge summary written'),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return RecordSection(
      title: 'Timeline',
      icon: Icons.timeline_rounded,
      emptyMessage: 'Nothing has happened in this consultation yet.',
      children: [
        for (final (index, event) in events.indexed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                        color: AppColors.teal, shape: BoxShape.circle),
                  ),
                  if (index < events.length - 1)
                    Container(
                        width: 2, height: 36, color: AppColors.lightTealTint),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.label, style: AppTextStyles.body),
                      Text(DateFormat('d MMM yyyy, h:mm a').format(event.at),
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Who this record was shared with, from the record itself: the treating
/// clinician and any lab or pharmacy it was sent to. Each view of the record
/// will be listed here once the backend exposes a patient access log.
class _SharedWith extends StatelessWidget {
  const _SharedWith({required this.record});

  final MedicalRecord record;

  @override
  Widget build(BuildContext context) {
    final rows = <({IconData icon, String name, String why})>[
      (
        icon: Icons.person_outline,
        name: record.consultation.clinicianLabel,
        why: 'Your clinician'
      ),
      for (final inv in record.investigations)
        if (inv.facility != null)
          (
            icon: Icons.science_outlined,
            name: inv.facility!.name,
            why: inv.testName
          ),
      for (final rx in record.prescriptions)
        if (rx.pharmacy != null)
          (
            icon: Icons.local_pharmacy_outlined,
            name: rx.pharmacy!.name,
            why: 'Your prescription'
          ),
    ];
    return RecordSection(
      title: 'Shared with',
      icon: Icons.shield_outlined,
      emptyMessage: '',
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Icon(row.icon, size: 20, color: AppColors.muted),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(row.name, style: AppTextStyles.body)),
                Text(row.why, style: AppTextStyles.caption),
              ],
            ),
          ),
        const Text(
          'Change who can see your record in Profile → Who can see my record.',
          style: AppTextStyles.caption,
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
