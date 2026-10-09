/// Every path and payload shape this app assumes about the Django REST API.
///
/// VERIFIED against github.com/campofo/carelite (commit read 2026-09-08) —
/// its README, `config/urls.py`, `accounts/{models,serializers,views,urls}.py`,
/// `appointments/{models,serializers,views}.py`, `facilities/{models,
/// serializers,views,matching}.py` — and against a live local instance of
/// that code (SQLite `demo.sqlite3`, `python manage.py runserver`) hit with
/// real requests: register, login, refresh, `/me`, patient-profile PATCH,
/// booking, `/api/match/`. Nothing below is a guess.
abstract final class ApiContract {
  // --- Auth (accounts app + simplejwt) --------------------------------
  static const String tokenObtain = '/api/auth/token/';
  static const String tokenRefresh = '/api/auth/token/refresh/';
  static const String tokenVerify = '/api/auth/token/verify/';
  static const String register = '/api/accounts/register/';
  static const String currentUser = '/api/accounts/me/';
  static const String patientProfile = '/api/accounts/me/patient-profile/';
  static const String clinicianProfile = '/api/accounts/me/clinician-profile/';

  static const String accessTokenKey = 'access';
  static const String refreshTokenKey = 'refresh';

  /// simplejwt's `TokenObtainPairSerializer` posts `USERNAME_FIELD`, and this
  /// User model does not override it — the field really is "username", not
  /// "email". `RegisterSerializer` also requires it (`AbstractUser.username`
  /// is required + unique). There is no login-by-email endpoint.
  ///
  /// The confirmed product design is still "sign in with email": this app
  /// satisfies both by registering with `username == email` (see
  /// [DjangoAuthRepository.registerWithEmail]) and posting whatever the
  /// patient types in the email field under this key. For the seeded demo
  /// accounts (`kofi`, `dr_adjei`, …) that value is a plain username, which
  /// still works — it's just not a "real" email, and the login screen no
  /// longer requires @ formatting for exactly this reason.
  static const String credentialField = 'username';

  // --- Clinicians & booking (accounts + appointments apps) ------------
  static const String clinicians = '/api/accounts/clinicians/';
  static String clinicianSlots(int clinicianId) =>
      '/api/accounts/clinicians/$clinicianId/slots/';
  static const String appointments = '/api/appointments/';
  static String appointmentAction(int id, String action) =>
      '/api/appointments/$id/$action/';

  // --- Pre-call checklist & calls (PT-PRECALL, PT-CALL) -----------------
  //
  // Verified live end-to-end on 2026-09-09: booked → confirmed →
  // both participants' checklist → initiated → accepted → polled → ended,
  // plus every rejection (partial checklist 400, accepting without your own
  // ack 403, ending twice 400 with a bare list body). See
  // docs/PROJECT_STATUS.md. The lifecycle is real; only the media
  // transport (`join_token`) is a stub — the backend's own PRD calls that
  // acceptable for this phase.
  static String appointmentPrecall(int appointmentId) =>
      '/api/appointments/$appointmentId/precall/';
  static String appointmentCall(int appointmentId) =>
      '/api/appointments/$appointmentId/call/';
  static String call(int callId) => '/api/calls/$callId/';
  static String callAction(int callId, String action) =>
      '/api/calls/$callId/$action/';

  /// The POST body field naming the clinician on a SPECIFIC booking.
  ///
  /// Verified live, and *not* what the obvious guess would be: posting
  /// `clinician_id` is rejected with
  /// `{"clinician": ["Required for a SPECIFIC booking."]}` — the serializer
  /// reads the plain relation name even though the response nests a full
  /// clinician object under the same key.
  static const String bookingClinicianField = 'clinician';

  // --- Notifications (notifications app) -------------------------------
  //
  // All four verified live against a running instance on 2026-09-08, with a
  // real seeded row (not an empty list): the list returns the standard
  // paginated envelope whose rows carry
  // {id, channel, type, title, body, payload, read_at, created_at};
  // unread-count returns {"unread": n}; read-all returns
  // {"marked_read": n}; and the per-row read returns the updated row and is
  // idempotent (a second POST is still 200, read_at unchanged).
  //
  // Ownership is enforced server-side: POSTing another user's notification id
  // is a 404, not a 403 — so the app never needs to filter by recipient.
  static const String notifications = '/api/notifications/';
  static const String notificationsUnreadCount =
      '/api/notifications/unread-count/';
  static const String notificationsReadAll = '/api/notifications/read-all/';
  static String notificationRead(String id) => '/api/notifications/$id/read/';

  // --- Medical records (consultations + prescriptions + investigations) -
  //
  // Every clinical artefact is consultation-scoped: there is no
  // `GET /api/prescriptions/` or `/api/investigations/` that returns
  // everything of mine. That shape is what forces the records detail screen
  // to fan out four requests for one consultation — see
  // docs/PROJECT_STATUS.md.
  static const String consultations = '/api/consultations/';
  static String consultation(String id) => '/api/consultations/$id/';
  static String consultationSummary(String id) =>
      '/api/consultations/$id/summary/';
  static String consultationNotes(String id) => '/api/consultations/$id/notes/';
  static String consultationPrescriptions(String id) =>
      '/api/consultations/$id/prescriptions/';
  static String consultationInvestigations(String id) =>
      '/api/consultations/$id/investigations/';

  // --- Facilities & the generic geo-matcher (facilities app) ----------
  //
  // There is no clinician equivalent of this: ClinicianProfile carries no
  // lat/lng at all (consultations are virtual). "Nearby clinicians" on Home
  // is therefore rating-sorted, not distance-sorted — see
  // DjangoProviderRepository.
  static const String facilities = '/api/facilities/';
  static const String match = '/api/match/';

  // --- Not shipped ------------------------------------------------------
  // No OTP endpoints exist on this backend at all (confirmed absent from
  // config/urls.py and every app's urls.py). Phone+OTP sign-in has no path
  // to call. DjangoAuthRepository.sendOtp/verifyOtp return
  // NotImplementedFailure and make no request.
}
