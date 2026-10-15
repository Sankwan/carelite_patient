import 'package:equatable/equatable.dart';

/// One event from the server's per-user socket (`ws/realtime/`).
///
/// The server sends `{"event": <name>, "data": {...}}`. Only the names this
/// app acts on are modelled; anything else is ignored rather than failing,
/// so the backend can add events without breaking older installs.
sealed class RealtimeEvent extends Equatable {
  const RealtimeEvent();

  static RealtimeEvent? fromJson(Object? json) {
    if (json is! Map) return null;
    final data = json['data'] is Map ? (json['data'] as Map) : const <String, dynamic>{};
    return switch (json['event']) {
      'call' when data['call_id'] != null => RealtimeCallChanged(
          callId: '${data['call_id']}',
          status: '${data['status'] ?? ''}',
        ),
      'message' when data['conversation_id'] != null =>
        RealtimeMessageArrived('${data['conversation_id']}'),
      'notification' => RealtimeNotification(
          id: '${data['id'] ?? ''}',
          type: '${data['type'] ?? ''}',
          title: '${data['title'] ?? ''}',
          body: '${data['body'] ?? ''}',
          payload: data['payload'] is Map
              ? (data['payload'] as Map).cast<String, dynamic>()
              : const {},
        ),
      _ => null,
    };
  }

  @override
  List<Object?> get props => [];
}

/// The socket came back after a drop or after the app was backgrounded.
/// Anything that happened meanwhile was missed, so listeners treat this as
/// "reload what you show".
final class RealtimeReconnected extends RealtimeEvent {
  const RealtimeReconnected();
}

final class RealtimeCallChanged extends RealtimeEvent {
  const RealtimeCallChanged({required this.callId, required this.status});

  final String callId;
  final String status;

  @override
  List<Object?> get props => [callId, status];
}

final class RealtimeMessageArrived extends RealtimeEvent {
  const RealtimeMessageArrived(this.conversationId);

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

final class RealtimeNotification extends RealtimeEvent {
  const RealtimeNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.payload = const {},
  });

  final String id;

  /// The backend's type name, e.g. `INCOMING_CALL`, `CLINICIAN_ASSIGNED`.
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [id, type, title, body, payload];
}

/// The narrow views each screen needs, so wiring code stays one line.
extension RealtimeStreams on Stream<RealtimeEvent> {
  /// Conversation list or unread count may have changed.
  Stream<void> get messagesChanged =>
      where((e) => e is RealtimeMessageArrived || e is RealtimeReconnected);

  /// The notification feed or its unread count may have changed.
  Stream<void> get notificationsChanged =>
      where((e) => e is RealtimeNotification || e is RealtimeReconnected);

  /// Ids of conversations with new messages; after a reconnect, [openId]
  /// too, since its messages may have been missed.
  Stream<String> conversationChanges(String openId) => expand((e) => switch (e) {
        RealtimeMessageArrived(:final conversationId) => [conversationId],
        RealtimeReconnected() => [openId],
        _ => const <String>[],
      });

  /// Ids of calls whose status changed; null after a reconnect, meaning
  /// "any call may have changed".
  Stream<String?> get callChanges => expand((e) => switch (e) {
        RealtimeCallChanged(:final callId) => [callId],
        RealtimeReconnected() => [null],
        _ => const <String?>[],
      });
}
