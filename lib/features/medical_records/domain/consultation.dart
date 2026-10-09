import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/display_name.dart';

/// Mirrors `consultations.models.Consultation.Status`.
enum ConsultationStatus {
  open('In progress'),
  closed('Completed');

  const ConsultationStatus(this.label);

  final String label;
}

/// One consultation — the unit every clinical record hangs off.
///
/// Verified against `consultations.serializers.ConsultationSerializer` on a
/// live instance. Note there is no patient or clinician *name* anywhere:
/// only usernames, because this backend has no name field at all.
class Consultation extends Equatable {
  const Consultation({
    required this.id,
    required this.appointmentId,
    required this.status,
    this.clinicianUsername,
    this.startedAt,
    this.endedAt,
    this.latestNoteVersion = 0,
  });

  factory Consultation.fromDjangoJson(Map<String, dynamic> row) {
    return Consultation(
      id: '${row['id']}',
      appointmentId: '${row['appointment']}',
      status: row['status'] == 'CLOSED'
          ? ConsultationStatus.closed
          : ConsultationStatus.open,
      clinicianUsername: row['clinician_username'] as String?,
      startedAt: _dateOrNull(row['started_at']),
      endedAt: _dateOrNull(row['ended_at']),
      latestNoteVersion: row['latest_note_version'] as int? ?? 0,
    );
  }

  final String id;
  final String appointmentId;
  final ConsultationStatus status;

  /// Null when the appointment had no clinician assigned (nullable
  /// server-side), which is why every screen reading this must have a
  /// fallback rather than a `!`.
  final String? clinicianUsername;

  final DateTime? startedAt;
  final DateTime? endedAt;

  /// 0 means the clinician wrote no note. Used to tell "no note" apart from
  /// "note not fetched yet" without a second request.
  final int latestNoteVersion;

  bool get hasNote => latestNoteVersion > 0;

  String get clinicianLabel => clinicianUsername == null
      ? 'Clinician unavailable'
      : formatUsername(clinicianUsername!);

  /// The date the record is filed under — when it happened, falling back to
  /// when it started. Null only if the server sent neither.
  DateTime? get occurredAt => endedAt ?? startedAt;

  /// "4 Sep 2026", or "Date unknown" rather than a misleading epoch date.
  String get dateLabel {
    final date = occurredAt;
    if (date == null) return 'Date unknown';
    return DateFormat('d MMM yyyy').format(date);
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  @override
  List<Object?> get props => [
        id, appointmentId, status, clinicianUsername,
        startedAt, endedAt, latestNoteVersion,
      ];
}
