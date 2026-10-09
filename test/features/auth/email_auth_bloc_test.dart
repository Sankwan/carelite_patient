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

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository authRepository;

  const user = AuthUser(id: '7', phone: '+233241234567', fullName: 'Esi Owusu');

  setUp(() {
    authRepository = _MockAuthRepository();
    when(() => authRepository.authStateChanges())
        .thenAnswer((_) => const Stream.empty());
  });

  group('email + password', () {
    blocTest<AuthBloc, AuthState>(
      'emits [authenticating, authenticated] when sign-in succeeds',
      build: () {
        when(() => authRepository.signInWithPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => const Result.ok(user));
        return AuthBloc(authRepository: authRepository);
      },
      act: (bloc) => bloc.add(const AuthEmailSignInRequested(
        email: 'esi@example.com',
        password: 'hunter2',
      )),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        const AuthState(status: AuthStatus.authenticated, user: user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'surfaces bad credentials without authenticating',
      build: () {
        when(() => authRepository.signInWithPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer(
          (_) async => const Result.err(AuthFailure('Incorrect email or password.')),
        );
        return AuthBloc(authRepository: authRepository);
      },
      act: (bloc) => bloc.add(const AuthEmailSignInRequested(
        email: 'esi@example.com',
        password: 'wrong',
      )),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.unauthenticated)
            .having((s) => s.user, 'user', isNull)
            .having((s) => s.failure?.message, 'message',
                'Incorrect email or password.'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'registration passes email, password and phone through together',
      build: () {
        when(() => authRepository.registerWithEmail(
              email: any(named: 'email'),
              password: any(named: 'password'),
              phone: any(named: 'phone'),
            )).thenAnswer((_) async => const Result.ok(user));
        return AuthBloc(authRepository: authRepository);
      },
      act: (bloc) => bloc.add(const AuthRegistrationRequested(
        email: 'esi@example.com',
        password: 'hunter2',
        phone: '+233241234567',
      )),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        const AuthState(status: AuthStatus.authenticated, user: user),
      ],
      verify: (_) => verify(() => authRepository.registerWithEmail(
            email: 'esi@example.com',
            password: 'hunter2',
            phone: '+233241234567',
          )).called(1),
    );
  });

  group('phone-only patient, no OTP endpoints yet', () {
    // This is a real, currently-true product state, not a hypothetical edge
    // case: the backend has shipped no OTP endpoints, so the fallback path
    // must fail visibly and leave the user unauthenticated.
    blocTest<AuthBloc, AuthState>(
      'requesting an OTP leaves the user signed out with a clear message',
      build: () {
        when(() => authRepository.sendOtp(any())).thenAnswer(
          (_) async => const Result.err(NotImplementedFailure(
            'Phone sign-in is coming soon. Please use your email and password.',
          )),
        );
        return AuthBloc(authRepository: authRepository);
      },
      act: (bloc) => bloc.add(const AuthOtpRequested('+233241234567')),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        isA<AuthState>()
            // Critically NOT otpSent — the app must not navigate to a screen
            // waiting for a code that will never arrive.
            .having((s) => s.status, 'status', AuthStatus.unauthenticated)
            .having((s) => s.failure, 'failure', isA<NotImplementedFailure>()),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'verifying an OTP never produces an authenticated state',
      build: () {
        when(() => authRepository.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otp: any(named: 'otp'),
            )).thenAnswer(
          (_) async => const Result.err(NotImplementedFailure()),
        );
        return AuthBloc(authRepository: authRepository);
      },
      act: (bloc) => bloc.add(const AuthOtpVerified(
        phoneNumber: '+233241234567',
        otp: '123456',
      )),
      verify: (bloc) {
        expect(bloc.state.status, isNot(AuthStatus.authenticated));
        expect(bloc.state.user, isNull);
      },
    );
  });
}
