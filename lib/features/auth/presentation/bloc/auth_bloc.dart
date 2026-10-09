import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthState()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    on<AuthOtpRequested>(_onOtpRequested);
    on<AuthOtpVerified>(_onOtpVerified);
    on<AuthEmailSignInRequested>(_onEmailSignInRequested);
    on<AuthRegistrationRequested>(_onRegistrationRequested);
    on<AuthProfileCompleted>(_onProfileCompleted);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final AuthRepository _authRepository;
  StreamSubscription<AuthUser?>? _authSubscription;

  Future<void> _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authSubscription?.cancel();
    await emit.forEach<AuthUser?>(
      _authRepository.authStateChanges(),
      onData: (user) => user == null
          ? const AuthState(status: AuthStatus.unauthenticated)
          : AuthState(status: AuthStatus.authenticated, user: user),
    );
  }

  Future<void> _onOtpRequested(
    AuthOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearFailure: true));
    final result = await _authRepository.sendOtp(event.phoneNumber);
    result.when(
      ok: (_) => emit(state.copyWith(status: AuthStatus.otpSent)),
      err: (failure) => emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        failure: failure,
      )),
    );
  }

  Future<void> _onOtpVerified(
    AuthOtpVerified event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearFailure: true));
    final result = await _authRepository.verifyOtp(
      phoneNumber: event.phoneNumber,
      otp: event.otp,
    );
    result.when(
      ok: (user) => emit(state.copyWith(status: AuthStatus.authenticated, user: user)),
      err: (failure) => emit(state.copyWith(
        status: AuthStatus.otpSent,
        failure: failure,
      )),
    );
  }

  Future<void> _onEmailSignInRequested(
    AuthEmailSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearFailure: true));
    final result = await _authRepository.signInWithPassword(
      email: event.email,
      password: event.password,
    );
    result.when(
      ok: (user) => emit(
        state.copyWith(status: AuthStatus.authenticated, user: user),
      ),
      err: (failure) => emit(
        state.copyWith(status: AuthStatus.unauthenticated, failure: failure),
      ),
    );
  }

  Future<void> _onRegistrationRequested(
    AuthRegistrationRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearFailure: true));
    final result = await _authRepository.registerWithEmail(
      email: event.email,
      password: event.password,
      phone: event.phone,
    );
    result.when(
      ok: (user) => emit(
        state.copyWith(status: AuthStatus.authenticated, user: user),
      ),
      err: (failure) => emit(
        state.copyWith(status: AuthStatus.unauthenticated, failure: failure),
      ),
    );
  }

  void _onProfileCompleted(
    AuthProfileCompleted event,
    Emitter<AuthState> emit,
  ) {
    final user = state.user;
    if (user == null) return;
    emit(state.copyWith(
      user: user.copyWith(
        hasCompletedProfile: true,
        fullName: event.fullName ?? user.fullName,
      ),
    ));
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
