import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/features/profile/data/django_access_repository.dart';
import 'package:carelite_app/features/profile/domain/access_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _response(int status, dynamic body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    );

Map<String, dynamic> _row({
  int id = 1,
  String status = 'PENDING',
  String? decidedAt,
}) =>
    {
      'id': id,
      'clinician_username': 'dr_adjei',
      'patient_username': 'kofi',
      'status': status,
      'has_access': status == 'ACTIVE',
      'reason': 'Reviewing your last visit',
      'requested_at': '2026-10-15T10:00:00Z',
      'decided_at': decidedAt,
    };

void main() {
  late _MockApiClient client;
  late DjangoAccessRepository repository;

  setUp(() {
    client = _MockApiClient();
    repository = DjangoAccessRepository(client);
  });

  test('reads requests targeting the signed-in patient', () async {
    when(() => client.get(ApiContract.accessRequests)).thenAnswer(
      (_) async => _response(200, {
        'count': 1,
        'results': [_row()],
      }),
    );

    final result = await repository.fetchRequests();

    final request = result.when(ok: (v) => v.single, err: (f) => throw f);
    expect(request.clinicianUsername, 'dr_adjei');
    expect(request.status, AccessRequestStatus.pending);
    expect(request.reason, 'Reviewing your last visit');
  });

  test('approving returns the updated, now-active request', () async {
    when(() => client.post(ApiContract.accessRequestAction('1', 'approve')))
        .thenAnswer((_) async => _response(
              200,
              _row(status: 'ACTIVE', decidedAt: '2026-10-15T11:00:00Z'),
            ));

    final result = await repository.approve('1');

    final request = result.when(ok: (v) => v, err: (f) => throw f);
    expect(request.status, AccessRequestStatus.active);
    expect(request.isActive, isTrue);
  });

  test('declining returns the updated, now-inactive request', () async {
    when(() => client.post(ApiContract.accessRequestAction('1', 'decline')))
        .thenAnswer((_) async => _response(200, _row(status: 'INACTIVE')));

    final result = await repository.decline('1');

    expect(
      result.when(ok: (v) => v.status, err: (_) => null),
      AccessRequestStatus.inactive,
    );
  });

  test('revoking a request that is no longer the patient\'s own fails cleanly',
      () async {
    when(() => client.post(ApiContract.accessRequestAction('1', 'revoke')))
        .thenAnswer((_) async => _response(403, {
              'detail': 'Only the patient can decide on this request.',
            }));

    final result = await repository.revoke('1');

    expect(
      result.when(ok: (_) => null, err: (f) => f.message),
      'Only the patient can decide on this request.',
    );
  });
}
