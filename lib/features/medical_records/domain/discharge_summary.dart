import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// The e-discharge summary, generated server-side when the appointment is
/// completed (`appointments.views.complete` → `generate_and_deliver_summary`).
///
/// A consultation that is still open genuinely has none, and the endpoint
/// returns **404** for that — not an empty body. That 404 is the reason the
/// repository maps this one endpoint's 404 to `null` rather than a failure.
class DischargeSummary extends Equatable {
  const DischargeSummary({
    required this.id,
    this.diagnosis = '',
    this.advice = '',
    this.prescriptions = '',
    this.followUpDate,
    this.generatedBy,
    this.generatedAt,
  });

  factory DischargeSummary.fromDjangoJson(Map<String, dynamic> row) {
    return DischargeSummary(
      id: '${row['id']}',
      diagnosis: row['diagnosis'] as String? ?? '',
      advice: row['advice'] as String? ?? '',
      // A free-text field on the summary, distinct from the structured
      // Prescription records — the clinician's own wording.
      prescriptions: row['prescriptions'] as String? ?? '',
      followUpDate: _dateOrNull(row['follow_up_date']),
      generatedBy: row['generated_by_username'] as String?,
      generatedAt: _dateOrNull(row['generated_at']),
    );
  }

  final String id;
  final String diagnosis;
  final String advice;
  final String prescriptions;
  final DateTime? followUpDate;
  final String? generatedBy;
  final DateTime? generatedAt;

  bool get isEmpty =>
      diagnosis.trim().isEmpty &&
      advice.trim().isEmpty &&
      prescriptions.trim().isEmpty;

  String? get followUpLabel {
    final date = followUpDate;
    if (date == null) return null;
    return DateFormat('d MMM yyyy').format(date);
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  @override
  List<Object?> get props =>
      [id, diagnosis, advice, prescriptions, followUpDate, generatedBy, generatedAt];
}
