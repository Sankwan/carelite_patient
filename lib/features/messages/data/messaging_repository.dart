import '../../../core/utils/result.dart';
import '../domain/chat_message.dart';
import '../domain/conversation.dart';

abstract class MessagingRepository {
  Future<Result<List<Conversation>>> fetchConversations();

  /// The most recent messages in a thread, oldest first.
  Future<Result<List<ChatMessage>>> fetchRecentMessages(String conversationId);

  Future<Result<ChatMessage>> send(String conversationId, String body);

  Future<Result<void>> markRead(String conversationId);

  Future<Result<int>> fetchUnreadCount();
}
