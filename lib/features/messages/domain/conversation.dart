import 'package:equatable/equatable.dart';

import '../../../core/utils/display_name.dart';

/// One patient–clinician thread, from the signed-in patient's side.
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.clinicianName,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageIsMine = false,
    this.unreadCount = 0,
  });

  factory Conversation.fromDjangoJson(
    Map<String, dynamic> row, {
    required String myUserId,
  }) {
    final other = (row['other_participant'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final last = (row['last_message'] as Map?)?.cast<String, dynamic>();
    return Conversation(
      id: '${row['id']}',
      clinicianName: clinicianDisplayName(
        fullName: realNameOrNull(other['full_name']),
        username: other['username'] as String? ?? 'Clinician',
      ),
      lastMessage: last?['body'] as String?,
      lastMessageAt: DateTime.tryParse(
        (last?['created_at'] ?? row['last_message_at']) as String? ?? '',
      )?.toLocal(),
      lastMessageIsMine: last != null && '${last['sender']}' == myUserId,
      unreadCount: row['unread_count'] as int? ?? 0,
    );
  }

  final String id;
  final String clinicianName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageIsMine;
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;

  Conversation copyWith({int? unreadCount}) => Conversation(
        id: id,
        clinicianName: clinicianName,
        lastMessage: lastMessage,
        lastMessageAt: lastMessageAt,
        lastMessageIsMine: lastMessageIsMine,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  @override
  List<Object?> get props => [
        id, clinicianName, lastMessage, lastMessageAt, lastMessageIsMine,
        unreadCount,
      ];
}
