import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../../config/env.dart';
import 'api_contract.dart';
import 'token_store.dart';

/// Thin Dio wrapper that attaches the access token and transparently
/// refreshes it once on a 401.
///
/// Replaces the role Supabase's SDK played: it owned session persistence and
/// silent refresh. Everything here is that job, done explicitly.
class ApiClient {
  ApiClient({required TokenStore tokenStore, Dio? dio})
      : _tokenStore = tokenStore,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = Env.djangoApiBaseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      // Never throw on a status code: every caller maps status to a Result,
      // so a 400 is data, not an exception to unwind through.
      ..validateStatus = ((int? _) => true)
      ..headers['Content-Type'] = 'application/json';

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.extra.containsKey(_skipAuth)) {
            final access = await _tokenStore.readAccess();
            if (access != null) {
              options.headers['Authorization'] = 'Bearer $access';
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          if (response.statusCode != 401 ||
              response.requestOptions.extra.containsKey(_retried) ||
              response.requestOptions.extra.containsKey(_skipAuth)) {
            return handler.next(response);
          }

          // One refresh attempt, then give up. Retrying repeatedly on a dead
          // refresh token would loop the user through silent failures.
          final refreshed = await _refreshAccessToken();
          if (!refreshed) {
            await _tokenStore.clear();
            _sessionExpired.add(null);
            return handler.next(response);
          }

          try {
            final retry = await _dio.fetch<dynamic>(
              response.requestOptions..extra[_retried] = true,
            );
            return handler.resolve(retry);
          } catch (_) {
            return handler.next(response);
          }
        },
      ),
    );
  }

  static const String _skipAuth = 'skipAuth';
  static const String _retried = 'retried';

  final Dio _dio;
  final TokenStore _tokenStore;
  final Logger _log = Logger('ApiClient');
  final StreamController<void> _sessionExpired = StreamController<void>.broadcast();

  /// Emits when the refresh token is dead and the user must sign in again.
  Stream<void> get onSessionExpired => _sessionExpired.stream;

  Future<void> dispose() => _sessionExpired.close();

  /// Options for endpoints that must not carry a bearer token — login,
  /// register and refresh itself.
  static Options get unauthenticated => Options(extra: {_skipAuth: true});

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get<dynamic>(path, queryParameters: query);

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _dio.post<dynamic>(path, data: data, options: options);

  Future<Response<dynamic>> patch(String path, {Object? data}) =>
      _dio.patch<dynamic>(path, data: data);

  Future<bool> _refreshAccessToken() async {
    final refresh = await _tokenStore.readRefresh();
    if (refresh == null) return false;

    try {
      final response = await _dio.post<dynamic>(
        ApiContract.tokenRefresh,
        data: {ApiContract.refreshTokenKey: refresh},
        options: unauthenticated,
      );
      final body = response.data;
      if (response.statusCode != 200 || body is! Map) return false;

      final access = body[ApiContract.accessTokenKey] as String?;
      if (access == null) return false;

      // Rotate-on-refresh is enabled server-side, so a new refresh token may
      // come back with it; persist it or the next refresh uses a dead one.
      final rotated = body[ApiContract.refreshTokenKey] as String?;
      if (rotated != null) {
        await _tokenStore.save(access: access, refresh: rotated);
      } else {
        await _tokenStore.saveAccess(access);
      }
      return true;
    } catch (error) {
      _log.warning('Token refresh failed', error);
      return false;
    }
  }
}
