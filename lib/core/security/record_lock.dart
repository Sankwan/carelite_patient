import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import '../storage/app_preferences.dart';

/// Guards the health record with the phone's own fingerprint, face or PIN.
///
/// Two levels, following common patient-portal practice:
/// * the **record lock** is optional — when on, Records and every record
///   screen ask once and stay unlocked for [unlockWindow], relocking when
///   the app goes to the background;
/// * a **sensitive result** asks every time it is opened, lock on or off.
///
/// The check is the OS biometric prompt with the device PIN as fallback.
/// It deters someone holding an unlocked phone; it is not encryption — the
/// data itself is protected on the server and in transit.
class RecordLock extends ChangeNotifier with WidgetsBindingObserver {
  RecordLock(this._preferences, {LocalAuthentication? auth, DateTime Function()? clock})
      : _auth = auth ?? LocalAuthentication(),
        _clock = clock ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
  }

  final AppPreferences _preferences;
  final LocalAuthentication _auth;
  final DateTime Function() _clock;

  static const Duration unlockWindow = Duration(minutes: 5);

  DateTime? _unlockedAt;

  bool get isEnabled => _preferences.recordLockEnabled;

  /// True when the record can be shown without asking.
  bool get isUnlocked {
    if (!isEnabled) return true;
    final at = _unlockedAt;
    return at != null && _clock().difference(at) < unlockWindow;
  }

  /// Whether this phone can show a fingerprint, face or PIN prompt at all.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Shows the OS prompt. True only when the person passed it.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlock() async {
    final ok = await authenticate('Unlock your health record');
    if (ok) {
      _unlockedAt = _clock();
      notifyListeners();
    }
    return ok;
  }

  /// Turning the lock on asks first, so nobody locks themselves out with a
  /// phone that has no fingerprint or PIN set up.
  Future<bool> setEnabled(bool value) async {
    if (value) {
      final ok = await authenticate('Confirm it’s you to turn on the record lock');
      if (!ok) return false;
      _unlockedAt = _clock();
    }
    await _preferences.setRecordLockEnabled(value: value);
    notifyListeners();
    return true;
  }

  void lockNow() {
    if (_unlockedAt == null) return;
    _unlockedAt = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) lockNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
