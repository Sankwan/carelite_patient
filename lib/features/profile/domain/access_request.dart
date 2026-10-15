import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// A clinician's consent request for this patient's details and files —
/// separate from consultation access, which a booked appointment already
/// grants. Mirrors `access.models.PatientDataAccess.Status`.
enum AccessRequestStatus {
  pending('Pending', 'Awaiting your decision'),
  active('Active', 'Can view your details'),
  inactive('Declined', 'No longer has access');

  const AccessRequestStatus(this.label, this.description);

  final String label;
  final String description;
}

class AccessRequest extends Equatable {
  const AccessRequest({
    required this.id,
    required this.clinicianUsername,
    required this.status,
    required this.requestedAt,
    this.reason = '',
    this.decidedAt,
  });

  factory AccessRequest.fromDjangoJson(Map<String, dynamic> row) {
    return AccessRequest(
      id: '${row['id']}',
      clinicianUsername: row['clinician_username'] as String? ?? '',
      status: _statusFrom(row['status'] as String?),
      reason: row['reason'] as String? ?? '',
      requestedAt: DateTime.parse(row['requested_at'] as String).toLocal(),
      decidedAt: row['decided_at'] == null
          ? null
          : DateTime.parse(row['decided_at'] as String).toLocal(),
    );
  }

  final String id;
  final String clinicianUsername;
  final AccessRequestStatus status;
  final String reason;
  final DateTime requestedAt;
  final DateTime? decidedAt;

  bool get isPending => status == AccessRequestStatus.pending;
  bool get isActive => status == AccessRequestStatus.active;

  String get requestedAtLabel => DateFormat('d MMM yyyy').format(requestedAt);

  static AccessRequestStatus _statusFrom(String? raw) {
    return switch (raw) {
      'ACTIVE' => AccessRequestStatus.active,
      'INACTIVE' => AccessRequestStatus.inactive,
      _ => AccessRequestStatus.pending,
    };
  }

  @override
  List<Object?> get props =>
      [id, clinicianUsername, status, reason, requestedAt, decidedAt];
}
