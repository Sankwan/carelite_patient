import 'package:equatable/equatable.dart';

/// One message in a thread.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.mine,
    required this.sentAt,
    this.isPending = false,
  });

  factory ChatMessage.fromDjangoJson(Map<String, dynamic> row) {
    return ChatMessage(
      id: '${row['id']}',
      body: row['body'] as String? ?? '',
      mine: row['mine'] as bool? ?? false,
      sentAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String body;

  /// Sent by the signed-in patient (the server computes this per request).
  final bool mine;
  final DateTime sentAt;

  /// Shown immediately while the send is in flight; replaced by the
  /// server's copy on success.
  final bool isPending;

  @override
  List<Object?> get props => [id, body, mine, sentAt, isPending];
}
