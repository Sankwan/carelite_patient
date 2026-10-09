import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/auth/data/auth_repository.dart';
import 'package:carelite_app/features/auth/domain/auth_user.dart';
import 'package:carelite_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:carelite_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:carelite_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Fake instead of a mocktail `Mock` for `authStateChanges()`: a Mock
/// returns `null` for an unstubbed `Stream` getter, so unless every test
/// stubs it explicitly, `emit.forEach` inside the Bloc throws. Reference
/// implementation for future feature Blocs facing the same shape.
class _FakeAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _FakeAuthRepository authRepository;

  const phoneNumber = '+233241234567';
  const otp = '123456';
  const user = AuthUser(id: 'user-1', phone: phoneNumber);

  setUp(() {
    authRepository = _FakeAuthRepository();
    when(() => authRepository.authStateChanges()).thenAnswer((_) => const Stream.empty());
  });

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emits [authenticating, otpSent] when sendOtp succeeds',
      build: () {
        when(() => authRepository.sendOtp(phoneNumber))
            .thenAnswer((_) async => const Result.ok(null));
        return AuthBloc(authRepository: authRepository);
      },
      act: (bloc) => bloc.add(const AuthOtpRequested(phoneNumber)),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        const AuthState(status: AuthStatus.otpSent),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [authenticating, unauthenticated+failure] when sendOtp fails',
      build: () {
        when(() => authRepository.sendOtp(phoneNumber))
            .thenAnswer((_) async => const Result.err(NetworkFailure()));
        return AuthBloc(authRepository: authRepository);
      },
      act: (bloc) => bloc.add(const AuthOtpRequested(phoneNumber)),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.unauthenticated)
            .having((s) => s.failure, 'failure', isA<NetworkFailure>()),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [authenticating, authenticated+user] when verifyOtp succeeds',
      build: () {
        when(() => authRepository.verifyOtp(phoneNumber: phoneNumber, otp: otp))
            .thenAnswer((_) async => const Result.ok(user));
        return AuthBloc(authRepository: authRepository);
      },
      act: (bloc) => bloc.add(const AuthOtpVerified(phoneNumber: phoneNumber, otp: otp)),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        const AuthState(status: AuthStatus.authenticated, user: user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthProfileCompleted carries the name through for the Home greeting',
      build: () => AuthBloc(authRepository: authRepository),
      seed: () => const AuthState(status: AuthStatus.authenticated, user: user),
      act: (bloc) =>
          bloc.add(const AuthProfileCompleted(fullName: 'Esi Owusu')),
      expect: () => [
        // Without the name the dashboard greets a "?" avatar until the next
        // auth-stream emission, which a profiles write does not trigger.
        isA<AuthState>()
            .having((s) => s.user?.hasCompletedProfile, 'hasCompletedProfile', isTrue)
            .having((s) => s.user?.fullName, 'fullName', 'Esi Owusu'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated] and calls signOut on AuthSignOutRequested',
      build: () {
        when(() => authRepository.signOut()).thenAnswer((_) async {});
        return AuthBloc(authRepository: authRepository);
      },
      seed: () => const AuthState(status: AuthStatus.authenticated, user: user),
      act: (bloc) => bloc.add(const AuthSignOutRequested()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
      verify: (_) => verify(() => authRepository.signOut()).called(1),
    );
  });
}
