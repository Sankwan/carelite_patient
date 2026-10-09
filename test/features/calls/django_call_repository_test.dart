import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/features/calls/data/django_call_repository.dart';
import 'package:carelite_app/features/calls/domain/call_session.dart';
import 'package:carelite_app/features/calls/domain/precall_checklist.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _response(int status, dynamic body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    );

void main() {
  late _MockApiClient client;
  late DjangoCallRepository repository;

  setUp(() {
    client = _MockApiClient();
    repository = DjangoCallRepository(client);
  });

  group('fetchPrecallStatus', () {
    test('parses the gate shape, verified live', () async {
      when(() => client.get(ApiContract.appointmentPrecall(15))).thenAnswer(
        (_) async => _response(200, {
          'appointment': 15,
          'acknowledgements': <dynamic>[],
          'you_acknowledged': true,
          'can_join': true,
          'both_ready': false,
        }),
      );

      final result = await repository.fetchPrecallStatus('15');

      final status = result.when(ok: (s) => s, err: (f) => throw f);
      expect(status.youAcknowledged, isTrue);
      expect(status.bothReady, isFalse);
    });
  });

  group('submitPrecallChecklist', () {
    test('posts all four booleans and re-fetches the gate shape', () async {
      when(() => client.post(
            ApiContract.appointmentPrecall(15),
            data: any(named: 'data'),
          )).thenAnswer((_) async => _response(200, {
            'participant_username': 'kofi',
            'quiet_location': true,
            'camera_mic_ok': true,
            'connection_ok': true,
            'documents_ready': true,
          }));
      when(() => client.get(ApiContract.appointmentPrecall(15))).thenAnswer(
        (_) async => _response(200, {
          'you_acknowledged': true,
          'can_join': true,
          'both_ready': false,
        }),
      );

      final result = await repository.submitPrecallChecklist(
        '15',
        const PrecallChecklist(
          quietLocation: true,
          cameraMicOk: true,
          connectionOk: true,
          documentsReady: true,
        ),
      );

      final body = verify(() => client.post(
            ApiContract.appointmentPrecall(15),
            data: captureAny(named: 'data'),
          )).captured.single as Map<String, dynamic>;
      expect(body, {
        'quiet_location': true,
        'camera_mic_ok': true,
        'connection_ok': true,
        'documents_ready': true,
      });
      // The POST response is only this user's own ack row — the caller
      // needs the full gate shape (does the OTHER participant's ack exist
      // too?), which only the GET carries.
      expect(result.when(ok: (s) => s.youAcknowledged, err: (_) => null), isTrue);
    });

    test('a partial checklist surfaces the server\'s own rejection', () async {
      when(() => client.post(
            ApiContract.appointmentPrecall(15),
            data: any(named: 'data'),
          )).thenAnswer((_) async => _response(400, {
            'non_field_errors': [
              'All checklist items must be confirmed before joining the call.',
            ],
          }));

      final result = await repository.submitPrecallChecklist(
        '15',
        const PrecallChecklist(quietLocation: true),
      );

      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure!.message, contains('All checklist items'));
    });
  });

  group('initiateCall', () {
    test('parses a freshly-initiated RINGING session', () async {
      when(() => client.post(
            ApiContract.appointmentCall(15),
            data: any(named: 'data'),
          )).thenAnswer((_) async => _response(201, {
            'id': 5,
            'appointment': 15,
            'initiated_by_username': 'kofi',
            'mode': 'VIDEO',
            'status': 'RINGING',
            'room': {
              'room_name': 'abc123',
              'join_token': 'stub-token-abc123',
            },
            'created_at': '2026-09-09T10:09:07Z',
            'accepted_at': null,
            'ended_at': null,
          }));

      final result = await repository.initiateCall('15', CallMode.video);

      final session = result.when(ok: (s) => s, err: (f) => throw f);
      expect(session.status, CallStatus.ringing);
      expect(session.isActive, isTrue);
      expect(session.joinToken, 'stub-token-abc123');
    });

    test('without your own pre-call ack the server 403s with its own reason',
        () async {
      when(() => client.post(
            ApiContract.appointmentCall(15),
            data: any(named: 'data'),
          )).thenAnswer((_) async => _response(403, {
            'detail': 'Complete the pre-call checklist before starting the call.',
          }));

      final result = await repository.initiateCall('15', CallMode.video);

      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure!.message, contains('pre-call checklist'));
    });
  });

  group('endCall', () {
    test('ending an already-ended call reads the bare-list error body',
        () async {
      // Verified live: this specific rejection comes back as a plain JSON
      // list, not {"detail": ...} — drfMessage must read both shapes.
      when(() => client.post(ApiContract.callAction(5, 'end')))
          .thenAnswer((_) async => _response(400, [
                'This call has already ended.',
              ]));

      final result = await repository.endCall('5');

      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure!.message, 'This call has already ended.');
    });

    test('a successful end parses the ENDED session', () async {
      when(() => client.post(ApiContract.callAction(5, 'end'))).thenAnswer(
        (_) async => _response(200, {
          'id': 5,
          'appointment': 15,
          'mode': 'VIDEO',
          'status': 'ENDED',
          'room': {'room_name': 'abc123', 'join_token': 'stub-token-abc123'},
          'created_at': '2026-09-09T10:09:07Z',
          'accepted_at': '2026-09-09T10:09:16Z',
          'ended_at': '2026-09-09T10:09:20Z',
        }),
      );

      final result = await repository.endCall('5');

      final session = result.when(ok: (s) => s, err: (f) => throw f);
      expect(session.status, CallStatus.ended);
      expect(session.isFinished, isTrue);
    });
  });

  test('a malformed response is a visible failure, never an uncaught throw',
      () async {
    when(() => client.get(ApiContract.call(5))).thenAnswer(
      // `room` is a String here, not the expected Map — the cast inside
      // CallSession.fromDjangoJson throws a TypeError.
      (_) async => _response(200, {'id': 5, 'room': 'not-a-map'}),
    );

    final result = await repository.fetchCall('5');

    expect(result.when(ok: (_) => null, err: (f) => f), isNotNull);
  });
}
