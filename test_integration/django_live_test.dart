import 'dart:math';

import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/core/network/api/token_store.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/features/auth/data/django_auth_repository.dart';
import 'package:carelite_app/features/calls/data/django_call_repository.dart';
import 'package:carelite_app/features/calls/domain/call_session.dart';
import 'package:carelite_app/features/calls/domain/precall_checklist.dart';
import 'package:carelite_app/features/find_clinician/data/django_clinician_repository.dart';
import 'package:carelite_app/features/find_clinician/domain/booking_request.dart';
import 'package:carelite_app/features/find_clinician/domain/search_filter.dart';
import 'package:carelite_app/features/home/data/django_appointment_repository.dart';
import 'package:carelite_app/features/home/data/django_provider_repository.dart';
import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:carelite_app/features/medical_records/data/django_records_repository.dart';
import 'package:carelite_app/features/medical_records/domain/consultation.dart';
import 'package:carelite_app/features/notifications/data/django_notification_repository.dart';
import 'package:carelite_app/features/profile/data/django_profile_repository.dart';
import 'package:carelite_app/features/profile/domain/patient_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hits a REAL local Django instance — not mocks. This is the actual
/// verifier-required round trip: register → login → authenticated request,
/// run against `github.com/campofo/carelite` on `demo.sqlite3`, checked out
/// and started for real (see docs/PROJECT_STATUS.md for exact steps).
///
/// Lives in test_integration/, a sibling of test/ — NOT inside it — so a
/// plain `flutter test` (CI, every other command in this session) never
/// discovers or runs it; same convention as supabase/tests/ for the RLS
/// suite. Run it explicitly, with a Django server up on 127.0.0.1:8000:
///   flutter test --dart-define=DJANGO_API_BASE_URL=http://127.0.0.1:8000 \
///     test_integration/django_live_test.dart
///
/// The --dart-define is required: [Env.djangoApiBaseUrl] defaults to
/// 10.0.2.2, the Android-emulator-only alias for the host — unreachable from
/// a plain `flutter test` VM (or desktop/web). Omitting it produces a 15s
/// DioExceptionType.connectionTimeout on every call, which the first draft
/// of this suite briefly mistook for the client code itself being broken.
///
/// One long sequential scenario, deliberately not N independent tests: the
/// first version of this file was N tests, and `package:test`'s default
/// intra-file concurrency ran several of them against the live server at
/// once — each doing its own register+login — which piled enough
/// auth-scoped requests into Django's dev server (single dev process,
/// `THROTTLE_AUTH=10/min`) to trip the throttle and, from there, produce
/// genuine 30s hangs. A live smoke test against shared mutable server state
/// should be one deterministic story, not a pile of racing ones — this is
/// that fix, not a workaround for a bug in the client code being tested
/// (`docs/PROJECT_STATUS.md` records the incident).
///
/// An in-memory fake TokenStore stands in for flutter_secure_storage, which
/// needs a platform channel the plain `flutter test` VM does not provide —
/// the network calls themselves are 100% real.
class _FakeTokenStore extends Fake implements TokenStore {
  String? access;
  String? refresh;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> saveAccess(String access) async => this.access = access;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }

  @override
  Future<bool> get hasSession async => refresh != null;
}

void main() {
  test(
    'register → login → /me → save profile → search, filter and book a '
    'clinician → see it on Home, all against a real Django server',
    () async {
      final tokenStore = _FakeTokenStore();
      final apiClient = ApiClient(tokenStore: tokenStore);
      var auth = DjangoAuthRepository(client: apiClient, tokenStore: tokenStore);
      addTearDown(() async {
        await auth.dispose();
        await apiClient.dispose();
      });

      final email =
          'live_test_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}'
          '@example.com';
      const password = 'Str0ngPass!23';
      const phone = '+233241234567';

      // --- register --------------------------------------------------
      final registerResult = await auth.registerWithEmail(
        email: email,
        password: password,
        phone: phone,
      );
      final registeredUser =
          registerResult.when(ok: (u) => u, err: (f) => throw f);
      expect(registeredUser.phone, phone);
      expect(registeredUser.hasCompletedProfile, isFalse,
          reason: 'no date_of_birth yet');
      expect(tokenStore.access, isNotNull);
      expect(tokenStore.refresh, isNotNull);

      // --- sign out, then back in with the same credentials ----------
      await auth.signOut();
      expect(tokenStore.access, isNull);

      final signInResult =
          await auth.signInWithPassword(email: email, password: password);
      expect(signInResult.when(ok: (u) => u.phone, err: (_) => null), phone);

      // --- wrong password is a real 401, never a session --------------
      await auth.signOut();
      final badLogin = await auth.signInWithPassword(
        email: email,
        password: 'wrong-password',
      );
      expect(badLogin.when(ok: (_) => null, err: (f) => f), isA<AuthFailure>());
      expect(tokenStore.access, isNull);

      // Sign back in for real before continuing.
      await auth.signInWithPassword(email: email, password: password);

      // --- OTP genuinely does not exist -------------------------------
      final otpResult = await auth.sendOtp(phone);
      expect(otpResult.when(ok: (_) => null, err: (f) => f),
          isA<NotImplementedFailure>());

      // --- save the real profile, then confirm the derived flag flips
      //     on the *next* session restore (not just in-memory) ---------
      final profileRepo = DjangoProfileRepository(apiClient);
      final saveResult = await profileRepo.saveProfile(
        userId: 'ignored-serverside',
        profile: PatientProfile(
          fullName: 'Esi Owusu',
          dateOfBirth: DateTime(2001), // Jan 1, 2001
          gender: Gender.female,
          bloodType: BloodType.oPositive,
        ),
      );
      expect(saveResult.when(ok: (_) => true, err: (_) => false), isTrue);

      await auth.dispose();
      auth = DjangoAuthRepository(client: apiClient, tokenStore: tokenStore);
      final restoredUser = await auth.authStateChanges().first;
      expect(restoredUser?.hasCompletedProfile, isTrue);

      // --- real clinicians, real Decimal-as-string fields --------------
      final providerRepo = DjangoProviderRepository(apiClient);
      final cliniciansResult =
          await providerRepo.fetchVerified(kind: ProviderKind.clinician);
      final clinicians =
          cliniciansResult.when(ok: (list) => list, err: (f) => throw f);
      expect(clinicians, isNotEmpty, reason: 'seed_demo must have run');
      expect(clinicians.every((p) => p.rating == null || p.rating! <= 5), isTrue);

      // --- Find a Clinician, through the production repository ---------
      final clinicianRepo = DjangoClinicianRepository(apiClient);

      final unfiltered = await clinicianRepo.search(const ClinicianFilter());
      final all = unfiltered.when(ok: (list) => list, err: (f) => throw f);
      expect(all, isNotEmpty);
      // Fixed server-side ordering: `-rating, username`. There is no
      // ?ordering= param, which is why the UI offers no sort control.
      final ratings = all.map((c) => c.rating ?? 0).toList();
      expect(
        ratings,
        orderedEquals(ratings.toList()..sort((a, b) => b.compareTo(a))),
        reason: 'the server returns highest-rated first',
      );

      // ?specialty= really narrows server-side (icontains).
      final bySpecialty = await clinicianRepo.search(
        ClinicianFilter(specialty: all.first.specialty ?? ''),
      );
      final narrowed = bySpecialty.when(ok: (list) => list, err: (f) => throw f);
      expect(narrowed, isNotEmpty);
      expect(narrowed.length, lessThanOrEqualTo(all.length));

      // A specialty nobody practices is an empty list, never an error — the
      // UI shows "no clinicians match those filters" for exactly this.
      final noMatch = await clinicianRepo.search(
        const ClinicianFilter(specialty: 'Zzzznotaspecialty'),
      );
      expect(noMatch.when(ok: (list) => list, err: (f) => throw f), isEmpty);

      // --- real slots for a real clinician -----------------------------
      final slotsResult =
          await clinicianRepo.fetchSlots(int.parse(clinicians.first.id));
      final slots = slotsResult.when(ok: (list) => list, err: (f) => throw f);
      expect(
        slots.every((slot) => slot.isAfter(DateTime.now())),
        isTrue,
        reason: 'times that have already passed must be filtered out',
      );

      // A clinician that does not exist is a clean failure, not a crash.
      final missingSlots = await clinicianRepo.fetchSlots(999999);
      expect(missingSlots.when(ok: (_) => null, err: (f) => f), isNotNull);

      // --- book through the repository, exactly as the UI does ---------
      final bookResult = await clinicianRepo.book(
        BookingRequest.specific(
          clinicianId: int.parse(clinicians.first.id),
          mode: BookingMode.scheduled,
          scheduledFor: DateTime.now().add(const Duration(days: 1)),
          reason: 'Integration test',
        ),
      );
      final bookedAppointment =
          bookResult.when(ok: (a) => a, err: (f) => throw f);
      expect(bookedAppointment.provider.displayName,
          clinicians.first.displayName);

      // A SCHEDULED booking with no time must surface the server's own
      // field error, not a generic "something went wrong".
      final missingTime = await clinicianRepo.book(
        BookingRequest.specific(
          clinicianId: int.parse(clinicians.first.id),
          mode: BookingMode.scheduled,
        ),
      );
      expect(
        missingTime.when(ok: (_) => null, err: (f) => f.message),
        contains('SCHEDULED'),
      );

      // An ANY booking nobody can satisfy returns the server's reason.
      final unmatched = await clinicianRepo.book(
        BookingRequest.any(
          mode: BookingMode.onDemand,
          specialty: 'Zzzznotaspecialty',
        ),
      );
      expect(
        unmatched.when(ok: (_) => null, err: (f) => f.message),
        contains('No available certified clinician'),
      );

      // --- notifications, through the production repository ------------
      final notificationRepo = DjangoNotificationRepository(apiClient);
      final unreadResult = await notificationRepo.fetchUnreadCount();
      expect(unreadResult.when(ok: (n) => n, err: (f) => throw f),
          greaterThanOrEqualTo(0));
      final feedResult = await notificationRepo.fetchAll();
      expect(feedResult.when(ok: (_) => true, err: (f) => throw f), isTrue);
      // Idempotent server-side, so it is safe to call on a fresh account.
      expect(
        (await notificationRepo.markAllRead())
            .when(ok: (_) => true, err: (f) => throw f),
        isTrue,
      );

      final appointmentRepo = DjangoAppointmentRepository(apiClient);
      final upcomingResult = await appointmentRepo.fetchUpcoming('ignored');
      final upcoming = upcomingResult.when(ok: (a) => a, err: (f) => throw f);
      expect(upcoming, isNotNull);
      expect(upcoming!.provider.displayName, clinicians.first.displayName);

      // --- the Appointments screen's own list + cancel ------------------
      final everyResult = await appointmentRepo.fetchAll();
      final every = everyResult.when(ok: (list) => list, err: (f) => throw f);
      expect(every, isNotEmpty, reason: 'we just booked one');
      // The two tabs together must account for every appointment.
      final active = every.where((a) => a.isActive).length;
      final finished = every.where((a) => !a.isActive).length;
      expect(active + finished, every.length);

      final cancelResult = await appointmentRepo.cancel(bookedAppointment.id);
      final cancelledAppointment =
          cancelResult.when(ok: (a) => a, err: (f) => throw f);
      expect(cancelledAppointment.status, AppointmentStatus.cancelled);
      expect(cancelledAppointment.isCancellable, isFalse);

      // Cancelling twice must surface the server's refusal, never succeed.
      final secondCancel = await appointmentRepo.cancel(bookedAppointment.id);
      expect(
        secondCancel.when(ok: (_) => null, err: (f) => f.message),
        contains('no longer be cancelled'),
      );

      // --- medical records, through the production repository ----------
      final recordsRepo = DjangoRecordsRepository(apiClient);
      final consultationsResult = await recordsRepo.fetchConsultations();
      // A brand-new account has none — a valid answer, not an error, and the
      // records screen must render it as "no records yet".
      final consultations =
          consultationsResult.when(ok: (list) => list, err: (f) => throw f);
      expect(consultations, isA<List<Consultation>>());

      // --- profile, through the production repository -------------------
      final accountResult = await profileRepo.fetchAccount();
      final account = accountResult.when(ok: (a) => a, err: (f) => throw f);
      expect(account.username, email);
      expect(account.dateOfBirthLabel, isNotNull,
          reason: 'the profile was saved earlier in this test');

      // --- pre-call checklist & call, through the production repository -
      //
      // This app has no clinician client, so the "other participant"
      // half of this is played by a second, independent session
      // authenticating as the seeded dr_adjei — exactly what a real
      // clinician app would do, driven here with the same DjangoCallRepository
      // this patient app ships (accept/decline are clinician-only actions
      // with no client-side repository method, so those two calls go
      // through the raw ApiClient — see docs/PROJECT_STATUS.md).
      final clinicianTokenStore = _FakeTokenStore();
      final clinicianApiClient = ApiClient(tokenStore: clinicianTokenStore);
      addTearDown(() async => clinicianApiClient.dispose());
      final clinicianAuth = DjangoAuthRepository(
        client: clinicianApiClient,
        tokenStore: clinicianTokenStore,
      );
      addTearDown(() async => clinicianAuth.dispose());
      // dr_adjei is a seeded PATIENT-app-incompatible account (role
      // CLINICIAN) — signInWithPassword refuses it by design (see
      // DjangoAuthRepository._rejectNonPatient), so this drives the raw
      // token endpoint instead, exactly as a clinician app would.
      final clinicianTokenResponse = await clinicianApiClient.post(
        ApiContract.tokenObtain,
        data: {'username': 'dr_adjei', 'password': 'carelite123'},
        options: ApiClient.unauthenticated,
      );
      expect(clinicianTokenResponse.statusCode, 200,
          reason: 'seed_demo must have run');
      await clinicianTokenStore.save(
        access: clinicianTokenResponse.data['access'] as String,
        refresh: clinicianTokenResponse.data['refresh'] as String,
      );

      // Raw lookup of dr_adjei's own ClinicianProfile id — deliberately not
      // through the formatted Provider (whose displayName is no longer the
      // raw username after the formatUsername change) and not assumed to
      // match `clinicians.first` from earlier in this test, which any
      // rating tie could reorder.
      final clinicianListResponse =
          await apiClient.get(ApiContract.clinicians);
      final clinicianRow = (clinicianListResponse.data['results'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((row) => row['username'] == 'dr_adjei');
      final drAdjeiId = clinicianRow['id'] as int;

      final callAppointment = await clinicianRepo.book(
        BookingRequest.specific(
          clinicianId: drAdjeiId,
          mode: BookingMode.scheduled,
          scheduledFor: DateTime.now().add(const Duration(days: 1)),
          reason: 'Pre-call/call live check',
        ),
      );
      final callAppointmentId =
          callAppointment.when(ok: (a) => a.id, err: (f) => throw f);

      // The clinician confirms — REQUESTED → CONFIRMED is clinician-only
      // server-side, so no patient-app repository has this action either.
      final confirmResponse = await clinicianApiClient.post(
        ApiContract.appointmentAction(int.parse(callAppointmentId), 'confirm'),
      );
      expect(confirmResponse.statusCode, 200);

      final callRepo = DjangoCallRepository(apiClient);
      final clinicianCallRepo = DjangoCallRepository(clinicianApiClient);

      // A partial checklist is refused with the server's own wording.
      final partial = await callRepo.submitPrecallChecklist(
        callAppointmentId,
        const PrecallChecklist(
            quietLocation: true, connectionOk: true, documentsReady: true),
      );
      expect(
        partial.when(ok: (_) => null, err: (f) => f.message),
        contains('All checklist items'),
      );

      final patientAck = await callRepo.submitPrecallChecklist(
        callAppointmentId,
        const PrecallChecklist(
          quietLocation: true, cameraMicOk: true,
          connectionOk: true, documentsReady: true,
        ),
      );
      final gateAfterPatient =
          patientAck.when(ok: (s) => s, err: (f) => throw f);
      expect(gateAfterPatient.youAcknowledged, isTrue);
      expect(gateAfterPatient.bothReady, isFalse,
          reason: 'the clinician has not confirmed their own checklist yet');

      final initiated = await callRepo.initiateCall(
        callAppointmentId,
        CallMode.video,
      );
      final ringingCall = initiated.when(ok: (c) => c, err: (f) => throw f);
      expect(ringingCall.status, CallStatus.ringing);
      // A Daily room exists only when the server has DAILY_API_KEY set; an
      // empty room_url must read as "no video", never as a broken link.
      expect(ringingCall.roomUrl == null || ringingCall.roomUrl!.startsWith('https://'),
          isTrue);

      // The clinician cannot accept before completing their OWN checklist —
      // the server's exact guard, verified live rather than assumed.
      final earlyAccept = await clinicianApiClient.post(
        ApiContract.callAction(int.parse(ringingCall.id), 'accept'),
      );
      expect(earlyAccept.statusCode, 403);
      expect(
        (earlyAccept.data as Map)['detail'],
        contains('pre-call checklist'),
      );

      await clinicianCallRepo.submitPrecallChecklist(
        callAppointmentId,
        const PrecallChecklist(
          quietLocation: true, cameraMicOk: true,
          connectionOk: true, documentsReady: true,
        ),
      );

      final acceptResponse = await clinicianApiClient.post(
        ApiContract.callAction(int.parse(ringingCall.id), 'accept'),
      );
      expect(acceptResponse.statusCode, 200);
      expect(acceptResponse.data['status'], 'ACCEPTED');

      // The patient's own poll — exactly what CallBloc's timer does — sees
      // the clinician's acceptance without the patient doing anything.
      final polled = await callRepo.fetchCall(ringingCall.id);
      final acceptedCall = polled.when(ok: (c) => c, err: (f) => throw f);
      expect(acceptedCall.status, CallStatus.accepted);
      expect(acceptedCall.elapsedSince(DateTime.now()), isNotNull);

      final ended = await callRepo.endCall(ringingCall.id);
      final endedCall = ended.when(ok: (c) => c, err: (f) => throw f);
      expect(endedCall.status, CallStatus.ended);
      expect(endedCall.isFinished, isTrue);

      // Ending an already-ended call surfaces the server's bare-list error
      // body, not a generic failure.
      final secondEnd = await callRepo.endCall(ringingCall.id);
      expect(
        secondEnd.when(ok: (_) => null, err: (f) => f.message),
        contains('already ended'),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
