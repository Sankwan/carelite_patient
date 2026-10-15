import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/profile/data/access_repository.dart';
import 'package:carelite_app/features/profile/domain/access_request.dart';
import 'package:carelite_app/features/profile/presentation/bloc/access_requests_bloc.dart';
import 'package:carelite_app/features/profile/presentation/bloc/access_requests_event.dart';
import 'package:carelite_app/features/profile/presentation/bloc/access_requests_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAccessRepository extends Mock implements AccessRepository {}

void main() {
  late _MockAccessRepository repository;

  final pending = AccessRequest(
    id: '1',
    clinicianUsername: 'dr_adjei',
    status: AccessRequestStatus.pending,
    requestedAt: DateTime(2026, 10, 15),
  );
  final active = AccessRequest(
    id: '2',
    clinicianUsername: 'dr_owusu',
    status: AccessRequestStatus.active,
    requestedAt: DateTime(2026, 10, 10),
  );

  setUp(() => repository = _MockAccessRepository());

  blocTest<AccessRequestsBloc, AccessRequestsState>(
    'loads and splits pending from decided',
    build: () {
      when(() => repository.fetchRequests())
          .thenAnswer((_) async => Result.ok([pending, active]));
      return AccessRequestsBloc(accessRepository: repository);
    },
    act: (bloc) => bloc.add(const AccessRequestsStarted()),
    verify: (bloc) {
      expect(bloc.state.pending, [pending]);
      expect(bloc.state.decided, [active]);
    },
  );

  blocTest<AccessRequestsBloc, AccessRequestsState>(
    'approving replaces just that row with the server\'s answer',
    seed: () => AccessRequestsState(requests: [pending, active]),
    build: () {
      final approved = AccessRequest(
        id: '1',
        clinicianUsername: 'dr_adjei',
        status: AccessRequestStatus.active,
        requestedAt: pending.requestedAt,
        decidedAt: DateTime(2026, 10, 15, 11),
      );
      when(() => repository.approve('1'))
          .thenAnswer((_) async => Result.ok(approved));
      return AccessRequestsBloc(accessRepository: repository);
    },
    act: (bloc) =>
        bloc.add(const AccessRequestDecided('1', AccessDecision.approve)),
    verify: (bloc) {
      expect(bloc.state.requests.firstWhere((r) => r.id == '1').isActive, isTrue);
      expect(bloc.state.decidingId, isNull);
    },
  );

  blocTest<AccessRequestsBloc, AccessRequestsState>(
    'a failed decision is shown and the row keeps its old status',
    seed: () => AccessRequestsState(requests: [pending]),
    build: () {
      when(() => repository.revoke('1')).thenAnswer(
        (_) async => const Result.err(NetworkFailure()),
      );
      return AccessRequestsBloc(accessRepository: repository);
    },
    act: (bloc) =>
        bloc.add(const AccessRequestDecided('1', AccessDecision.revoke)),
    verify: (bloc) {
      expect(bloc.state.failure, isA<NetworkFailure>());
      expect(bloc.state.requests.single.status, AccessRequestStatus.pending);
    },
  );
}
