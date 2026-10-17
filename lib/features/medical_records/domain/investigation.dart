import 'package:equatable/equatable.dart';

import 'care_facility.dart';

/// Mirrors `investigations.models.InvestigationRequest.Status`.
enum InvestigationStatus {
  requested('Requested'),
  accepted('Accepted by facility'),
  sampleDone('Sample taken'),
  resultUploaded('Result ready'),
  cancelled('Cancelled');

  const InvestigationStatus(this.label);

  final String label;
}

enum InvestigationPriority {
  routine('Routine'),
  urgent('Urgent'),
  stat('Immediate');

  const InvestigationPriority(this.label);

  final String label;
}

/// Whether the patient may see the result yet. Results go to the clinician
/// first and reach the patient when reviewed or after 48 hours; a sensitive
/// result waits for the clinician (docs/BACKEND_REVIEW_2026-10-16.md,
/// "Results and records"). Today's backend sends none of this, which reads
/// as [released] — what the app has always shown.
enum ResultRelease {
  released,

  /// With the clinician; auto-releases after the review window.
  pendingReview,

  /// Sensitive: shown only after the clinician releases it.
  heldForClinician,
}

/// How a value compares with the lab's reference range.
enum ResultFlag {
  normal(''),
  low('Low'),
  high('High'),
  criticalLow('Critically low'),
  criticalHigh('Critically high');

  const ResultFlag(this.label);

  final String label;

  bool get isAbnormal => this != normal;
  bool get isCritical => this == criticalLow || this == criticalHigh;

  static ResultFlag from(String? code) => switch (code?.toUpperCase()) {
        'L' => low,
        'H' => high,
        'LL' => criticalLow,
        'HH' => criticalHigh,
        _ => normal,
      };
}

/// One measured value of a result, e.g. "Haemoglobin 10.2 g/dL (12–16)".
class ResultValue extends Equatable {
  const ResultValue({
    required this.name,
    required this.value,
    this.unit = '',
    this.referenceRange = '',
    this.flag = ResultFlag.normal,
  });

  factory ResultValue.fromDjangoJson(Map<String, dynamic> row) {
    return ResultValue(
      name: row['name'] as String? ?? '',
      value: '${row['value'] ?? ''}',
      unit: row['unit'] as String? ?? '',
      referenceRange: row['reference_range'] as String? ?? '',
      flag: ResultFlag.from(row['flag'] as String?),
    );
  }

  final String name;
  final String value;
  final String unit;
  final String referenceRange;
  final ResultFlag flag;

  @override
  List<Object?> get props => [name, value, unit, referenceRange, flag];
}

/// A scanned page, photo or PDF the lab attached — the original the typed
/// values were taken from.
class ResultAttachment extends Equatable {
  const ResultAttachment(
      {required this.url, required this.name, this.isPdf = false});

  final String url;
  final String name;
  final bool isPdf;

  @override
  List<Object?> get props => [url, name, isPdf];
}

/// A lab or imaging test the clinician ordered.
///
/// This is the patient-facing end of the flow the product is built around:
/// a clinician orders the test, the patient is notified, and only then is a
/// nearby facility offered. The patient never browses labs directly — which
/// is why this type is read-only here and has no "book a lab" action.
class Investigation extends Equatable {
  const Investigation({
    required this.id,
    required this.testName,
    required this.status,
    this.isImaging = false,
    this.priority = InvestigationPriority.routine,
    this.reason = '',
    this.facility,
    this.resultText,
    this.resultUploadedAt,
    this.hasResultFile = false,
    this.values = const [],
    this.attachments = const [],
    this.release = ResultRelease.released,
    this.isSensitive = false,
  });

  factory Investigation.fromDjangoJson(Map<String, dynamic> row) {
    final result = row['result'] as Map<String, dynamic>?;
    final attachments = <ResultAttachment>[
      for (final a in (result?['attachments'] as List?) ?? const [])
        if (a is Map && a['url'] is String)
          ResultAttachment(
            url: a['url'] as String,
            name: a['name'] as String? ?? 'Attachment',
            isPdf: '${a['content_type'] ?? ''}'.contains('pdf'),
          ),
    ];
    // Today's single `file`: openable only once the server returns an
    // absolute (signed) link; a bare /media/ path isn't served (R3).
    final file = result?['file'];
    if (attachments.isEmpty && file is String && file.startsWith('http')) {
      attachments.add(ResultAttachment(
          url: file,
          name: 'Result file',
          isPdf: file.toLowerCase().contains('.pdf')));
    }
    return Investigation(
      id: '${row['id']}',
      testName: row['test_name'] as String? ?? 'Test',
      isImaging: row['type'] == 'IMAGING',
      status: _statusFrom(row['status'] as String?),
      priority: _priorityFrom(row['priority'] as String?),
      reason: row['reason'] as String? ?? '',
      facility: CareFacility.fromDjangoJson(
        row['assigned_facility'] as Map<String, dynamic>?,
      ),
      resultText: result?['result_text'] as String?,
      resultUploadedAt:
          DateTime.tryParse(result?['uploaded_at'] as String? ?? '')?.toLocal(),
      hasResultFile: file != null || attachments.isNotEmpty,
      values: [
        for (final v in (result?['values'] as List?) ?? const [])
          if (v is Map) ResultValue.fromDjangoJson(v.cast<String, dynamic>()),
      ],
      attachments: attachments,
      release: switch (row['release_status']) {
        'PENDING_REVIEW' => ResultRelease.pendingReview,
        'HELD' => ResultRelease.heldForClinician,
        _ => ResultRelease.released,
      },
      isSensitive: row['is_sensitive'] == true,
    );
  }

  final String id;
  final String testName;
  final bool isImaging;
  final InvestigationStatus status;
  final InvestigationPriority priority;
  final String reason;

  /// Null until the test is routed to a lab or imaging centre.
  final CareFacility? facility;
  final String? resultText;
  final DateTime? resultUploadedAt;
  final bool hasResultFile;
  final List<ResultValue> values;
  final List<ResultAttachment> attachments;
  final ResultRelease release;

  /// Asks for the fingerprint or PIN every time it is opened.
  final bool isSensitive;

  bool get hasResult =>
      (resultText != null && resultText!.trim().isNotEmpty) ||
      hasResultFile ||
      values.isNotEmpty;

  bool get isVisibleToPatient => release == ResultRelease.released;

  static InvestigationStatus _statusFrom(String? value) => switch (value) {
        'ACCEPTED' => InvestigationStatus.accepted,
        'SAMPLE_DONE' => InvestigationStatus.sampleDone,
        'RESULT_UPLOADED' => InvestigationStatus.resultUploaded,
        'CANCELLED' => InvestigationStatus.cancelled,
        _ => InvestigationStatus.requested,
      };

  static InvestigationPriority _priorityFrom(String? value) => switch (value) {
        'URGENT' => InvestigationPriority.urgent,
        'STAT' => InvestigationPriority.stat,
        _ => InvestigationPriority.routine,
      };

  @override
  List<Object?> get props => [
        id,
        testName,
        isImaging,
        status,
        priority,
        reason,
        facility,
        resultText,
        resultUploadedAt,
        hasResultFile,
        values,
        attachments,
        release,
        isSensitive,
      ];
}
