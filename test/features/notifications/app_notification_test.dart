import 'package:carelite_app/features/notifications/domain/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(String type, Map<String, dynamic> payload) => {
      'id': 1,
      'type': type,
      'title': 't',
      'body': '',
      'payload': payload,
      'created_at': '2026-10-16T08:00:00Z',
    };

void main() {
  test('a new message points at its conversation', () {
    final n = AppNotification.fromDjangoJson(
      _row('NEW_MESSAGE', {'conversation_id': 7}),
    );
    expect(n.type, NotificationType.newMessage);
    expect(n.conversationId, 7);
  });

  test('a cancelled appointment is its own type, not a generic card', () {
    final n = AppNotification.fromDjangoJson(
      _row('APPOINTMENT_CANCELLED', {'appointment_id': 3, 'replaced_by': 4}),
    );
    expect(n.type, NotificationType.appointmentCancelled);
    expect(n.appointmentId, 3);
  });

  test('a result points at the consultation it belongs to', () {
    final n = AppNotification.fromDjangoJson(_row('RESULT_READY', {
      'investigation_id': 9,
      'consultation_id': 12,
      'appointment_id': 3,
    }));
    expect(n.type, NotificationType.resultReady);
    expect(n.consultationId, 12);
  });
}
