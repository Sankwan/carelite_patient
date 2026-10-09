import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the simplejwt access/refresh pair.
///
/// Secure storage rather than SharedPreferences: these tokens authenticate
/// every request against real patient health data, so they belong in the
/// Keychain / EncryptedSharedPreferences, not in a plaintext plist that any
/// backup or rooted device exposes. This is the job Supabase's SDK used to
/// do internally and that a hand-rolled JWT client has to do for itself.
class TokenStore {
  const TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessKey = 'carelite.jwt.access';
  static const _refreshKey = 'carelite.jwt.refresh';

  static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<String?> readAccess() => _storage.read(key: _accessKey);

  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  /// Rotate-on-refresh returns a new access token, and may return a new
  /// refresh token too — persist whichever arrived.
  Future<void> saveAccess(String access) =>
      _storage.write(key: _accessKey, value: access);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<bool> get hasSession async => (await readRefresh()) != null;
}
