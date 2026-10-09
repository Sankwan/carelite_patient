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
  });

  factory Investigation.fromDjangoJson(Map<String, dynamic> row) {
    final result = row['result'] as Map<String, dynamic>?;
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
      // The file is served from Django's MEDIA_URL and needs an
      // authenticated fetch the app does not do yet, so its presence is
      // surfaced without pretending it can be opened.
      hasResultFile: result?['file'] != null,
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

  bool get hasResult =>
      (resultText != null && resultText!.trim().isNotEmpty) || hasResultFile;

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
        id, testName, isImaging, status, priority, reason,
        facility, resultText, resultUploadedAt,
        hasResultFile,
      ];
}
