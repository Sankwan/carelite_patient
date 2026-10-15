import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../../auth/data/auth_repository.dart';
import 'change_password_event.dart';
import 'change_password_state.dart';

class ChangePasswordBloc extends Bloc<ChangePasswordEvent, ChangePasswordState> {
  ChangePasswordBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const ChangePasswordState()) {
    on<ChangePasswordSubmitted>(_onSubmitted);
  }

  final AuthRepository _authRepository;

  Future<void> _onSubmitted(
    ChangePasswordSubmitted event,
    Emitter<ChangePasswordState> emit,
  ) async {
    emit(state.copyWith(
      status: ChangePasswordStatus.submitting,
      clearFailure: true,
    ));
    try {
      final result = await _authRepository.changePassword(
        oldPassword: event.oldPassword,
        newPassword: event.newPassword,
      );
      result.when(
        ok: (_) => emit(state.copyWith(status: ChangePasswordStatus.done)),
        err: (failure) => emit(state.copyWith(
          status: ChangePasswordStatus.idle,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: ChangePasswordStatus.idle,
        failure: UnexpectedFailure(
          'Could not change your password (${e.runtimeType}).',
        ),
      ));
    }
  }
}
