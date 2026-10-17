import 'package:carelite_app/core/security/record_lock.dart';
import 'package:carelite_app/core/storage/app_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuth extends Mock implements LocalAuthentication {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(const AuthenticationOptions()));

  late _MockAuth auth;
  late DateTime now;
  late RecordLock lock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = _MockAuth();
    now = DateTime(2026, 10, 17, 9);
    lock = RecordLock(AppPreferences(await SharedPreferences.getInstance()), auth: auth, clock: () => now);
    when(() => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => true);
  });

  test('off by default, so the record is open', () {
    expect(lock.isEnabled, isFalse);
    expect(lock.isUnlocked, isTrue);
  });

  test('turning it on asks first and starts an unlocked window', () async {
    expect(await lock.setEnabled(true), isTrue);
    expect(lock.isUnlocked, isTrue);

    now = now.add(RecordLock.unlockWindow);
    expect(lock.isUnlocked, isFalse);
  });

  test('a failed prompt leaves the lock off', () async {
    when(() => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => false);

    expect(await lock.setEnabled(true), isFalse);
    expect(lock.isEnabled, isFalse);
  });

  test('going to the background locks it again', () async {
    await lock.setEnabled(true);
    lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(lock.isUnlocked, isFalse);

    await lock.unlock();
    expect(lock.isUnlocked, isTrue);
  });
}
