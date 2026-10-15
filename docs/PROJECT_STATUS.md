# CareLite patient app — project status

Last reviewed 15 Oct 2026. `flutter analyze` clean, 346 tests passing; the
live suite in `test_integration/` passes against the current backend.
Application id `com.carelitehealth.patient`, app name "Carelite". The
launcher icon comes from `assets/icon/carelite_patient_logo.png`; regenerate
it with `dart run flutter_launcher_icons`.

The docs folder has three files:

- **PROJECT_STATUS.md** (this file) — what is built, how to run it, how the
  app talks to the backend, and what to do next.
- **[PRODUCT_PATHWAY.md](PRODUCT_PATHWAY.md)** — what the product is meant
  to do, and the open product decisions.
- **[BACKEND_REQUESTS_PATIENT.md](BACKEND_REQUESTS_PATIENT.md)** — every
  ask of the backend developer, with `PT-` IDs.

## Added on 15 Oct 2026

- Real names everywhere (clinicians shown as "Dr. First Last"); profile
  save writes first/last name.
- Switching clinician is one server call (`replaces`); no client-side
  cancel.
- Video: "Join video" opens the Daily room once the call is accepted.
- Messages tab: inbox, threads, optimistic send, unread badge on the tab.
- Realtime socket (`lib/core/realtime/`): one connection while signed in
  and in the foreground, exponential backoff, token refresh on close code
  4001, and a catch-up reload after any reconnect. Drives the bell and
  message badges, open threads, call status and a banner for new
  notifications. Polling stays as the fallback.
- Sign-out revokes the refresh token server-side (best-effort; offline
  sign-out still clears the device).
- Incoming calls: a clinician's call opens a ringing screen with Answer and
  Decline; Answer goes through the pre-call checklist if needed, then
  joins the existing call. Only while the app is open — PT-N4.
- Change password: Profile → Change password, through
  `POST /api/auth/password-change/`. "Forgot password" is not built —
  blocked by PT-N2a (the reset link opens `localhost:4200`).
- Vitals trend: Records → "Vitals trend" lists every reading newest-first
  (`GET /api/patients/{id}/vitals/`).
- Record access / consent: Profile → "Who can see my record" — approve,
  decline or revoke a clinician's request; a GENERIC notification with an
  `access_request_id` opens it directly from the bell.

Next: a patient-started conversation once PT-C10 lands (the clinician's
user UUID isn't exposed yet), then "forgot password" once PT-N2a is
fixed. After that: phone/OTP sign-up (PT-N1) and push delivery for a
closed app (PT-N4) are the two biggest remaining gaps — see
`docs/BACKEND_REQUESTS_PATIENT.md` for the full list.

## Running it

Backend (Django + Channels, cloned at `~/Development/carelite`; venv,
`.env` and a freshly migrated and seeded `db.sqlite3` are set up — the
committed `demo.sqlite3` is out of date, see PT-B3):

```bash
cd ~/Development/carelite && source .venv/bin/activate
python manage.py runserver 0.0.0.0:8000   # Daphne: serves HTTP and ws/
```

Demo logins: patient `kofi`, clinician `dr_adjei`, password `carelite123`.

App:

```bash
flutter run --dart-define=DJANGO_API_BASE_URL=http://10.0.2.2:8000
```

`10.0.2.2` is the Android emulator's address for the host machine and is
the default there. In a browser the default is `http://localhost:8000`, so
this works with no extra flags when the emulator is not available:

```bash
flutter run -d chrome
```

The backend allows any browser origin while `DEBUG` is on. The place name
on Home is not shown in the browser (reverse geocoding is phone-only). Demo logins, password `carelite123`: patients `kofi`, `ama`,
`yaw`, `akua`. Clinician accounts (`dr_adjei`, …) are refused by this app on
purpose.

Tests:

```bash
flutter analyze && flutter test
# against a running server:
flutter test --dart-define=DJANGO_API_BASE_URL=http://127.0.0.1:8000 \
  test_integration/django_live_test.dart
```

Fresh backend setup: Python 3.12 venv, `pip install -r requirements.txt`,
`cp .env.example .env`, `cp demo.sqlite3 db.sqlite3`, and add `10.0.2.2` to
`DJANGO_ALLOWED_HOSTS` in `.env`.

## What is built

| Screen | State |
|---|---|
| Splash, onboarding (3 slides), enable location | Working |
| Log in / register with email and password | Working against the live backend |
| "I don't have an email" (phone + OTP) | Screen exists; says phone sign-in is coming soon. No request is made |
| Complete Profile | Saves date of birth, sex, blood group. Full name, emergency contact and photo are collected or shown but have nowhere to be saved |
| Home | Greeting, initials, real place name, upcoming appointment, top clinicians, recent activity, unread bell |
| Find a Clinician (General Care) | "Available now" filter, highest rated first, "Match me" |
| Find Specialists | Specialty chips and search; lists nobody until a specialty is picked |
| Clinician profile and booking | Scheduled (real slots) or on demand; named clinician or any available. A refused booking says why and offers other clinicians |
| Appointments | Upcoming / Past, cancel with confirmation, Join call. After a cancel, other clinicians are offered |
| Pre-call checklist and call | Ring, accept, end are real, polled, and pushed live over the realtime socket. Video opens via Daily once a key is configured. The patient can answer an incoming call (ringing screen, Answer/Decline), not just start one. Declined, unanswered after 45 s, or connection lost: the patient is told and offered other clinicians or a retry |
| Records | Consultation list; summary, notes, prescriptions, tests and results per record. The assigned lab or pharmacy shows address, hours, **Directions** and **Call**. "Vitals trend" lists every reading newest-first |
| Notifications | List, live unread badge, mark read / all read. An access-request notification opens "Who can see my record" directly |
| Profile | Account and medical details, sign out (revokes the session server-side), change password, "Who can see my record" (approve/decline/revoke a clinician's access request) |
| Messages | Inbox, threads, optimistic send, live-updating unread badge |

Not built at all: payments, insurance, push notifications for a closed
app, in-person visits, rating a clinician, test consent, pharmacy
pickup/delivery, reschedule, "forgot password" (blocked by PT-N2a), phone
sign-up. Each is in BACKEND_REQUESTS_PATIENT.md.

## How the app is put together

- Flutter 3.44, Dart ≥ 3.4, Material 3.
- `lib/features/<name>/{data,domain,presentation}`. One Bloc per feature
  (`flutter_bloc`), `get_it` for dependency injection registered by hand in
  `lib/bootstrap.dart`, `go_router` for navigation. No code generation.
- Repositories return `Result<T>` and never throw. Every Bloc has a
  catch-all so no screen can hang on a spinner.
- HTTP through one `ApiClient` (`dio`) with a refresh-on-401 interceptor.
  Tokens live in secure storage. All paths are in `ApiContract`.
- The rule the whole app follows: **nothing on screen claims something the
  backend can't do.** If a feature is missing, the screen says so or the
  control is absent. No invented names, distances or statuses.

## Backend behaviour the app depends on

These were found by running against the live server. Breaking any of them
breaks the app.

- **Login is by `username`.** There is no email login. The app registers
  with `username == email`, then posts whatever is typed in the email field
  as `username`. That is why the seeded accounts work by typing `kofi`.
- **No name is exposed anywhere.** The app shows `dr_adjei` as "Dr. Adjei"
  through one formatter (`formatUsername`). The patient greeting shows no
  name; the avatar shows initials from the username.
- **"Profile complete" is derived:** a patient is complete once
  `date_of_birth` is set.
- **Every list is paginated**, 20 per page, as `{count, next, previous,
  results}`. Only `POST /api/match/` returns a bare list. The app reads the
  **first page only** for appointments, notifications and clinicians.
- **`rating` and `consultation_fee` are strings** (`"4.80"`), parsed with
  `double.tryParse`.
- **Booking posts `clinician`, not `clinician_id`.** The wrong name is
  silently ignored by the server.
- **Appointment statuses are uppercase:** `REQUESTED, CONFIRMED,
  IN_PROGRESS, COMPLETED, CANCELLED`. `clinician` can be null.
  `scheduled_at` is null for an on-demand booking.
- **A missing discharge summary is a 404**, treated as "not written yet",
  for that endpoint only.
- **Records cost four requests per consultation** (summary, notes,
  prescriptions, tests), fired in parallel when a record is opened.
- **Clinician filters are server-side** (`?specialty=`, `?online=true`).
  Ordering is fixed at `-rating, username`. Sending `?online=false` returns
  only offline clinicians, so the app omits it instead.
- **There is no clinician detail endpoint.** The profile screen is built
  from the list row, so it cannot be opened from a link or a notification.
- **`ANY` booking is synchronous:** it returns a booked appointment or a
  400. There is no "searching" state.
- **Notifications are one row per channel** (`IN_APP`, `SMS`, `PUSH`); the
  app filters to `IN_APP` when reading the list. `unread-count` itself
  now counts `IN_APP` only (PT-B1, fixed), so the app reads the cheap
  endpoint directly again.
- **Calls:** both sides must submit the four-item checklist before starting
  or accepting. `room_url` (Daily) is only set if `DAILY_API_KEY` is
  configured — otherwise the call screen has no video, by design, not a
  bug. Ending a call twice returns 400 with a bare-list body.
- **Non-patient accounts are refused at sign-in** by the app
  (`DjangoAuthRepository._rejectNonPatient`), based on `role`.

## Known gaps in the app itself

Not waiting on anyone — these are the app's own.

1. **Not release-ready on Android:** the release build is signed with the
   debug key, and the backend URL is plain `http`; a release build needs a
   signing key and an `https` URL.
2. **Six packages are installed and never imported:** `local_auth`,
   `google_maps_flutter`, `image_picker`, `file_picker`,
   `permission_handler`, `flutter_local_notifications`. They slow the build
   and two of them already forced build workarounds.
3. **Three empty feature folders** (`booking`, `payments`,
   `doctor_profile`) are left over from the first design.
4. **Lists stop at 20 rows** (see above) — appointments, notifications,
   clinicians. Messages and access-requests have the same ceiling.
5. **No crash reporting or analytics**, and no CI.
6. **No live tests for push-while-closed or a WebSocket under a flaky
   connection** beyond the backoff/reconnect unit tests — the realtime
   client has never been exercised against a real dropped connection on
   a device, only mocked ones.

## Suggested order of work

1. Remove the unused packages and leftover folders.
2. Follow `next` on paginated lists.
3. Release setup: signing key and an `https` backend URL.
4. As backend items land, in the order given in BACKEND_REQUESTS_PATIENT.md:
   PT-C10 (clinician user UUID, unblocks patient-started conversations),
   then PT-N2a ("forgot password"), then phone sign-up and push.
