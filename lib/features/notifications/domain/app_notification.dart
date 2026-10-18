import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Mirrors `notifications.models.Notification.Type` — verified against the
/// live backend, which sends these exact uppercase values.
///
/// The original Figma Notifications screen invented its own card taxonomy
/// (lab/pharmacy approval, dispatch status…). Those do not exist here, and
/// PAYMENT has no backend behind it yet (payments are deferred). These are
/// what the server can actually send, so they are what the UI is built from.
enum NotificationType {
  incomingCall('Incoming call'),
  clinicianAssigned('Clinician assigned'),
  appointmentCancelled('Appointment cancelled'),
  appointmentConfirmed('Appointment confirmed'),
  consultationStarted('Consultation started'),
  consultationCompleted('Consultation complete'),
  appointmentMissed('Missed appointment'),
  callMissed('Missed call'),
  resultReady('Result ready'),
  newMessage('New message'),
  payment('Payment'),
  generic('Notification');

  const NotificationType(this.label);

  final String label;
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.body = '',
    this.readAt,
    this.payload = const {},
  });

  factory AppNotification.fromDjangoJson(Map<String, dynamic> row) {
    return AppNotification(
      id: '${row['id']}',
      type: _typeFrom(row['type'] as String?),
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      readAt: row['read_at'] == null
          ? null
          : DateTime.parse(row['read_at'] as String).toLocal(),
      payload: (row['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  /// Free-form JSON the server attaches — e.g. `{"investigation_id": 3}` on a
  /// RESULT_READY, `{"appointment_id": 9}` on a CLINICIAN_ASSIGNED. Used to
  /// decide where tapping the notification should go.
  final Map<String, dynamic> payload;

  bool get isUnread => readAt == null;

  /// The id this notification points at, if any — read defensively because
  /// payload is a JSONField the server can shape freely.
  int? get appointmentId => _intFrom(payload['appointment_id']);
  int? get investigationId => _intFrom(payload['investigation_id']);
  int? get accessRequestId => _intFrom(payload['access_request_id']);
  int? get consultationId => _intFrom(payload['consultation_id']);
  int? get conversationId => _intFrom(payload['conversation_id']);

  /// "2:30 PM" today, "Yesterday", else "4 Sep" — computed, never stored.
  String relativeLabel({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final difference = day.difference(today).inDays;
    return switch (difference) {
      0 => DateFormat('h:mm a').format(createdAt),
      -1 => 'Yesterday',
      _ => DateFormat('d MMM').format(createdAt),
    };
  }

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      payload: payload,
    );
  }

  static int? _intFrom(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static NotificationType _typeFrom(String? value) => switch (value) {
        'INCOMING_CALL' => NotificationType.incomingCall,
        'CLINICIAN_ASSIGNED' => NotificationType.clinicianAssigned,
        'APPOINTMENT_CANCELLED' => NotificationType.appointmentCancelled,
        // Proposed in the backend review (R19, R21–R23); handled ahead so
        // they work the day the server sends them.
        'APPOINTMENT_CONFIRMED' => NotificationType.appointmentConfirmed,
        'CONSULTATION_STARTED' => NotificationType.consultationStarted,
        'CONSULTATION_COMPLETED' => NotificationType.consultationCompleted,
        'APPOINTMENT_MISSED' => NotificationType.appointmentMissed,
        'CALL_MISSED' => NotificationType.callMissed,
        'RESULT_READY' => NotificationType.resultReady,
        'NEW_MESSAGE' => NotificationType.newMessage,
        'PAYMENT' => NotificationType.payment,
        _ => NotificationType.generic,
      };

  @override
  List<Object?> get props => [id, type, title, body, createdAt, readAt, payload];
}
