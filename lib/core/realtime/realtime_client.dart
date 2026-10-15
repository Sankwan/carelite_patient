import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';
import '../network/api/token_store.dart';
import 'realtime_event.dart';

/// The app's one live connection to the server.
///
/// Everything here is a speed-up over polling, never the only path: every
/// screen that listens still loads over HTTP on open and on pull-to-refresh.
/// A dropped socket costs immediacy, not correctness.
abstract class RealtimeClient {
  Stream<RealtimeEvent> get events;

  /// Opens the socket if it is not open. Safe to call repeatedly.
  void connect();

  /// Closes the socket and stops reconnecting. [endSession] is for
  /// sign-out: the next connect is then a fresh start, not a catch-up.
  Future<void> disconnect({bool endSession = false});
}

/// Connects to `ws/realtime/?token=<access>` on the API host.
///
/// A dropped connection is retried with exponential backoff (1s, 2s, 4s …
/// capped at 30s). The server closes with 4001 when the access token is
/// missing or expired; [refreshSession] is then asked to renew it before
/// the next attempt, since only an HTTP request can trigger a refresh.
class WebSocketRealtimeClient implements RealtimeClient {
  WebSocketRealtimeClient({
    required TokenStore tokenStore,
    required Future<void> Function() refreshSession,
    WebSocketChannel Function(Uri uri)? connector,
    Duration Function(int attempt)? backoff,
  })  : _tokenStore = tokenStore,
        _refreshSession = refreshSession,
        _connector = connector ?? WebSocketChannel.connect,
        _backoff = backoff ?? _defaultBackoff;

  static const int _unauthorized = 4001;

  final TokenStore _tokenStore;
  final Future<void> Function() _refreshSession;
  final WebSocketChannel Function(Uri uri) _connector;
  final Duration Function(int attempt) _backoff;
  final Logger _log = Logger('Realtime');
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  int _attempt = 0;
  bool _wanted = false;
  bool _opening = false;
  bool _connectedBefore = false;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  void connect() {
    _wanted = true;
    if (_channel != null || _opening) return;
    _retry?.cancel();
    unawaited(_open());
  }

  @override
  Future<void> disconnect({bool endSession = false}) async {
    _wanted = false;
    if (endSession) _connectedBefore = false;
    _retry?.cancel();
    _attempt = 0;
    await _close();
  }

  Future<void> _open() async {
    _opening = true;
    try {
      final token = await _tokenStore.readAccess();
      if (!_wanted) return;
      if (token == null) {
        _scheduleRetry();
        return;
      }
      final channel = _connector(socketUri(Env.djangoApiBaseUrl, token));
      _channel = channel;
      _subscription = channel.stream.listen(
        _onData,
        onDone: () => _onClosed(channel.closeCode),
        onError: (Object error) => _log.fine('Socket error: $error'),
        cancelOnError: false,
      );
    } catch (error) {
      _log.fine('Socket open failed: $error');
      _channel = null;
      _scheduleRetry();
    } finally {
      _opening = false;
    }
  }

  void _onData(dynamic raw) {
    Object? json;
    try {
      json = raw is String ? jsonDecode(raw) : null;
    } on FormatException {
      return;
    }
    if (json is Map && json['event'] == 'connected') {
      _attempt = 0;
      // The first connection of a session has missed nothing: every screen
      // is loading fresh anyway.
      if (_connectedBefore) _events.add(const RealtimeReconnected());
      _connectedBefore = true;
      return;
    }
    final event = RealtimeEvent.fromJson(json);
    if (event != null) _events.add(event);
  }

  Future<void> _onClosed(int? code) async {
    await _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (!_wanted) return;
    if (code == _unauthorized) {
      try {
        await _refreshSession();
      } catch (_) {
        // The next attempt reads whatever token is stored; if the session
        // is truly dead the app signs out and calls disconnect().
      }
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_wanted) return;
    _retry?.cancel();
    _retry = Timer(_backoff(_attempt++), () {
      if (_wanted && _channel == null) unawaited(_open());
    });
  }

  Future<void> _close() async {
    final channel = _channel;
    _channel = null;
    await _subscription?.cancel();
    _subscription = null;
    await channel?.sink.close();
  }

  static Duration _defaultBackoff(int attempt) {
    final seconds = 1 << attempt.clamp(0, 5);
    return Duration(seconds: seconds > 30 ? 30 : seconds);
  }

  /// `http://host:8000` → `ws://host:8000/ws/realtime/?token=…`, and
  /// https → wss. The token rides in the query because browsers cannot set
  /// headers on a WebSocket; that is the server's contract.
  static Uri socketUri(String apiBaseUrl, String token) {
    final base = Uri.parse(apiBaseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/realtime/',
      queryParameters: {'token': token},
    );
  }
}
