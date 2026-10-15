import 'package:equatable/equatable.dart';

/// Mirrors `calls.models.CallSession.Status` — verified against a live
/// instance through the full lifecycle (ring → accept → end).
enum CallStatus {
  ringing('Ringing…'),
  accepted('Connected'),
  declined('Declined'),
  ended('Call ended'),
  missed('Missed call');

  const CallStatus(this.label);

  final String label;
}

enum CallMode { video, voice }

/// One call attempt for an appointment.
///
/// [roomUrl] is the Daily.co video room both participants open. It is
/// empty when the server has no Daily API key configured; the call then
/// still rings, connects and ends, but there is no video to join.
class CallSession extends Equatable {
  const CallSession({
    required this.id,
    required this.appointmentId,
    required this.status,
    this.mode = CallMode.video,
    this.initiatedByUsername,
    this.roomName,
    this.roomUrl,
    this.createdAt,
    this.acceptedAt,
    this.endedAt,
  });

  factory CallSession.fromDjangoJson(Map<String, dynamic> row) {
    final room = row['room'] as Map<String, dynamic>?;
    return CallSession(
      id: '${row['id']}',
      appointmentId: '${row['appointment']}',
      status: _statusFrom(row['status'] as String?),
      mode: row['mode'] == 'VOICE' ? CallMode.voice : CallMode.video,
      initiatedByUsername: row['initiated_by_username'] as String?,
      roomName: room?['room_name'] as String?,
      roomUrl: _nonEmpty(room?['room_url']),
      createdAt: _dateOrNull(row['created_at']),
      acceptedAt: _dateOrNull(row['accepted_at']),
      endedAt: _dateOrNull(row['ended_at']),
    );
  }

  final String id;
  final String appointmentId;
  final CallStatus status;
  final CallMode mode;
  final String? initiatedByUsername;
  final String? roomName;
  final String? roomUrl;

  bool get hasVideoRoom => roomUrl != null;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;

  bool get isRinging => status == CallStatus.ringing;
  bool get isActive => status == CallStatus.ringing || status == CallStatus.accepted;
  bool get isFinished => !isActive;

  /// How long an accepted call has run — null until accepted, frozen at
  /// [endedAt] once it has.
  Duration? elapsedSince(DateTime now) {
    final start = acceptedAt;
    if (start == null) return null;
    final end = endedAt ?? now;
    return end.difference(start);
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static CallStatus _statusFrom(String? value) => switch (value) {
        'ACCEPTED' => CallStatus.accepted,
        'DECLINED' => CallStatus.declined,
        'ENDED' => CallStatus.ended,
        'MISSED' => CallStatus.missed,
        _ => CallStatus.ringing,
      };

  static String? _nonEmpty(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [
        id, appointmentId, status, mode, initiatedByUsername,
        roomName, roomUrl, createdAt, acceptedAt, endedAt,
      ];
}
