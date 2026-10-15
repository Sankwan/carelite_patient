import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/api/drf_error.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';
import '../domain/chat_message.dart';
import '../domain/conversation.dart';
import 'messaging_repository.dart';

/// Messaging against `messaging.views.ConversationViewSet`.
class DjangoMessagingRepository implements MessagingRepository {
  DjangoMessagingRepository(this._client, {required this.currentUserId});

  final ApiClient _client;

  /// Resolved lazily: the signed-in user's id, used to tell which side of a
  /// thread sent the last message.
  final Future<String?> Function() currentUserId;

  static const int _pageSize = 20;

  @override
  Future<Result<List<Conversation>>> fetchConversations() async {
    try {
      final response = await _client.get(ApiContract.conversations);
      final results = _results(response);
      if (results == null) return Result.err(_failureFor(response));
      final me = await currentUserId() ?? '';
      try {
        return Result.ok(results
            .map((row) => Conversation.fromDjangoJson(row, myUserId: me))
            .toList(growable: false));
      } catch (e) {
        return Result.err(
          UnexpectedFailure('Could not read your messages (${e.runtimeType}).'),
        );
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<List<ChatMessage>>> fetchRecentMessages(
    String conversationId,
  ) async {
    try {
      // The server pages oldest-first, 20 at a time, so page 1 is the start
      // of the thread. The latest messages are on the last page; the one
      // before it is fetched too so a short last page still has context.
      final path = ApiContract.conversationMessages(conversationId);
      final first = await _client.get(path);
      final firstResults = _results(first);
      if (firstResults == null) return Result.err(_failureFor(first));
      final count = (first.data as Map)['count'] as int? ?? firstResults.length;
      final lastPage = count == 0 ? 1 : (count + _pageSize - 1) ~/ _pageSize;

      var rows = firstResults;
      if (lastPage > 1) {
        final pages = await Future.wait([
          if (lastPage - 1 > 1) _client.get(path, query: {'page': lastPage - 1}),
          _client.get(path, query: {'page': lastPage}),
        ]);
        final fetched = <Map<String, dynamic>>[];
        for (final page in pages) {
          final results = _results(page);
          if (results == null) return Result.err(_failureFor(page));
          fetched.addAll(results);
        }
        rows = lastPage - 1 > 1 ? fetched : [...firstResults, ...fetched];
      }
      try {
        return Result.ok(
          rows.map(ChatMessage.fromDjangoJson).toList(growable: false),
        );
      } catch (e) {
        return Result.err(
          UnexpectedFailure('Could not read this conversation (${e.runtimeType}).'),
        );
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<ChatMessage>> send(String conversationId, String body) async {
    try {
      final response = await _client.post(
        ApiContract.conversationMessages(conversationId),
        data: {'body': body},
      );
      if (response.statusCode == 201 && response.data is Map) {
        return Result.ok(ChatMessage.fromDjangoJson(
          (response.data as Map).cast<String, dynamic>(),
        ));
      }
      return Result.err(_failureFor(response));
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<void>> markRead(String conversationId) async {
    try {
      final response =
          await _client.post(ApiContract.conversationRead(conversationId));
      if (response.statusCode == 200) return const Result.ok(null);
      return Result.err(_failureFor(response));
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<int>> fetchUnreadCount() async {
    try {
      final response = await _client.get(ApiContract.conversationsUnreadCount);
      final unread = response.data is Map ? (response.data as Map)['unread'] : null;
      if (response.statusCode != 200 || unread is! int) {
        return const Result.err(NetworkFailure());
      }
      return Result.ok(unread);
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  List<Map<String, dynamic>>? _results(Response<dynamic> response) {
    if (response.statusCode != 200 || response.data is! Map) return null;
    final results = (response.data as Map)['results'];
    if (results is! List) return null;
    return results.cast<Map<String, dynamic>>();
  }

  Failure _failureFor(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status == 401) {
      return const AuthFailure('Your session has expired. Please sign in again.');
    }
    if (status == 403 || status == 400) {
      return ValidationFailure(drfMessage(response.data));
    }
    if (status == 404) {
      return const UnexpectedFailure('This conversation is no longer available.');
    }
    return const NetworkFailure();
  }
}
