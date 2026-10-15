# CareLite backend — requests from the patient app

Companion to the clinician app's `BACKEND_REQUESTS.md`, which you already
have. This one covers what the **patient** app (`carelite_app`) needs.
Where a request is the same change as one in the clinician document, it is
marked "same as clinician Xn" and only the patient-side detail is added
here — build it once.

Checked against `github.com/campofo/carelite` @ `main` on 15 Oct 2026
(14 local apps — `vitals`, `access` and `messaging` have landed since the
9 Oct check, plus a `channels`/`daphne` realtime layer). IDs in this
document start with `PT-`.

## Contents

- [Summary and priority](#summary-and-priority)
- [Part 0 — Bugs and gaps in existing endpoints](#part-0--bugs-and-gaps-in-existing-endpoints)
- [Part 1 — Small changes to existing endpoints](#part-1--small-changes-to-existing-endpoints)
- [Part 2 — New endpoints for screens the app already has](#part-2--new-endpoints-for-screens-the-app-already-has)
- [Part 3 — Labs and pharmacy, patient side](#part-3--labs-and-pharmacy-patient-side)
- [Part 4 — Payments](#part-4--payments)
- [Part 5 — In-person visits](#part-5--in-person-visits)
- [Part 6 — Notifications the patient should receive](#part-6--notifications-the-patient-should-receive)
- [Appendix A — What the patient app uses today](#appendix-a--what-the-patient-app-uses-today)
- [Appendix B — Open product questions](#appendix-b--open-product-questions)

## Summary and priority

Size: S = under a day, M = a few days, L = a week or more. Status is as of
15 Oct 2026, checked against `github.com/campofo/carelite` @ `main`.

**Since the 9 Oct review:** `vitals`, `access` (consent) and `messaging`
landed as new apps, plus a `channels`/`daphne` realtime layer at
`ws/realtime/`. The app now uses names, status/date filters, the richer
appointment payload, one-step replace, logout, Daily video rooms,
messaging and the realtime socket — see "Delivered" below for the exact
list. Building against this version surfaced six new asks (PT-B3, C10,
C11, C12, N2a, S1) and confirmed three more deliveries the app hasn't
wired up yet (N2, N11, N12).

| Pri | ID | Request | Size | Status |
|---|---|---|---|---|
| P0 | PT-B1 | `unread-count` counts each event once per channel | S | ✅ Done |
| P0 | PT-B2 | Patient is not told when a booking is confirmed or cancelled | S | Open |
| P0 | PT-B3 | `demo.sqlite3` in the repo is behind the migrations | S | **New** |
| P1 | PT-C1 | Names on user, clinician and appointment responses | S | ✅ Done |
| P1 | PT-C2 | Emergency contact on `PatientProfile` | S | Open |
| P1 | PT-C3 | Filters and ordering on `GET /api/appointments/` | S | ✅ Done |
| P1 | PT-C4 | `consultation_id` and `active_call_id` on appointments | S | ✅ Done |
| P1 | PT-C5 | Clinician list: search, more fields, detail endpoint | S–M | Partial (full_name done) |
| P1 | PT-C6 | Specialties list | S | Open |
| P1 | PT-C7 | Cancel with a reason; reschedule | S–M | Open |
| P1 | PT-C9 | Replace an appointment in one step | S | ✅ Done |
| P1 | PT-C10 | Expose the clinician's **user** UUID on clinician/appointment responses | S | **New** |
| P1 | PT-C11 | Ordering or a cursor on conversation messages | S | **New** |
| P1 | PT-N1 | Phone sign-up and login with OTP | M | Open |
| P1 | PT-N2 | Password reset and change password | M | Backend ready, app pending |
| P1 | PT-N2a | Password-reset link opens a mobile deep link, not `localhost:4200` | S | **New** |
| P1 | PT-N3 | Logout (refresh-token blacklist) | S | ✅ Done |
| P2 | PT-C12 | Caller's full name and `appointment_id` in the INCOMING_CALL payload | S | **New** |
| P2 | PT-N4 | Real push delivery (FCM) | M | Open |
| P2 | PT-N5 | Real call media | M–L | ✅ Done (Daily, when `DAILY_API_KEY` set) |
| P2 | PT-N6 | "All my prescriptions / tests" lists | S | Open |
| P2 | PT-N7 | Rate a clinician | M | Open |
| P2 | PT-N8 | Profile photo upload | S | Open |
| P2 | PT-N9 | Insurance on `PatientProfile` | S–M | Open |
| P2 | PT-N13 | Authenticated result-file download; PDF export | S–M | Open |
| P2 | PT-L1 | Patient accepts or declines an ordered test | M | Open |
| P2 | PT-L2 | Pickup or delivery for a prescription | M | Open |
| P3 | PT-N10 | Messaging | L | ✅ Done |
| P3 | PT-N11 | Vitals history | M | Backend ready, app pending |
| P3 | PT-N12 | Record access / consent | M | Backend ready, app pending |
| P3 | PT-P1 | Pay for a consultation, test, prescription | L | Open |
| P3 | PT-P2 | Featured clinicians first | S | Open |
| P3 | PT-S1 | WebSocket token travels in the query string (access-log exposure) | S | **New** |
| P3 | PT-V1–V3 | In-person visits | M–L | Open |

Suggested order: PT-B2, B3 → C2, C6, C7 → C10, C11, C12 → N1, N2a, N4 →
Part 3 → payments.

## Part 0 — Bugs and gaps in existing endpoints

### PT-B1. `GET /api/notifications/unread-count/` over-counts — ✅ Done

Same as clinician **B3**. `notify()` wrote one row per channel (`IN_APP`,
`SMS`, `PUSH`), and the count included all of them, so one incoming call
counted as 3.

- **Fixed:** the endpoint now counts `IN_APP` rows only. The app has
  switched back from the heavier `?unread=true` + client-side filter
  workaround to calling this endpoint directly.

### PT-B2. The patient is not told what happens to their booking

`notify()` is called in exactly three places: a new booking (to the
clinician), an incoming call, and a result upload (to the patient).
Nothing is sent to the patient when a clinician **confirms**, **cancels**,
**starts** or **completes** an appointment, orders a test, writes a
prescription, or assigns a lab or pharmacy.

- **Ask:** see [Part 6](#part-6--notifications-the-patient-should-receive).
  The two that matter most now are `APPOINTMENT_CONFIRMED` and
  `APPOINTMENT_CANCELLED`.

### PT-B3. The committed `demo.sqlite3` cannot be migrated — new, P0

A fresh clone's `demo.sqlite3` is behind the current migrations:
`python manage.py migrate` fails with
`duplicate column name: is_pregnant` (and similar) rather than applying
cleanly. The only way to get a runnable database today is to delete it and
run `migrate` + `seed_demo` from empty, which also means the fixed
clinician/patient usernames referenced in onboarding docs and sample
curl commands may not match what gets seeded.

- **Ask:** either drop the checked-in `demo.sqlite3` from the repo (a
  README step to `migrate && seed_demo` is enough, and avoids a stale
  binary file in git), or regenerate and recommit it after every
  migration that touches it. Please also confirm the exact `seed_demo`
  usernames/password so onboarding docs across both apps can cite one
  source of truth instead of each rediscovering them.

---

## Part 1 — Small changes to existing endpoints

### PT-C1. Names — ✅ Done

Same as clinician **C1**. `first_name` and `last_name` already existed on
`AbstractUser`; no serializer exposed them.

- **Delivered:** `UserSerializer`/`RegisterSerializer` expose writable
  `first_name`/`last_name` and a read-only `full_name`;
  `PublicClinicianSerializer` and the clinician nested in
  `AppointmentSerializer` expose `full_name`; consultations expose
  `clinician_name`. The app formats a clinician with a real name as
  "Dr. First Last" and saves the patient's name back on profile save.

### PT-C2. Emergency contact

- **Today:** `PatientProfile` has `emergency_flag` (boolean, "needs faster
  attention") and nothing else.
- **Ask:** `emergency_contact_name`, `emergency_contact_phone`,
  `emergency_contact_relationship` on `PatientProfile`, patient-writable.
  Leave `emergency_flag` as it is.

### PT-C3. Filters on `GET /api/appointments/` — ✅ Done

Same as clinician **C3**. The patient app used to read one page of 20 and
split Upcoming / Past on the phone, so a patient's 21st appointment never
showed.

- **Delivered:** `?status=` (comma list) and `?from=&to=` on
  `scheduled_at`/`created_at`. No `?ordering=` yet — default is still
  whatever the queryset's natural order is; worth confirming it is
  `-created_at` so "most recent first" doesn't depend on insertion order.

### PT-C4. More fields on the appointment response — ✅ Done

Same as clinician **C2**: `consultation_id` (null until started) and
`active_call_id` (id of a `RINGING`/`ACCEPTED` call, else null).

- **Delivered**, plus `patient_id`, `patient_name` and
  `cancellation_reason` on the same response, which weren't asked for
  but close real gaps (the replaced-appointment toast reads
  `cancellation_reason`).

### PT-C5. Clinician directory — partial (full_name delivered)

- **Today:** `GET /api/accounts/clinicians/` supports `?specialty=`
  (contains) and `?online=true`, ordered `-rating, username`. Each row is
  `id, username, full_name, specialty, bio, years_experience,
  consultation_fee, is_online, rating` (`full_name` landed with **C1**).
  There is still no `?search=`, no detail endpoint, and no user UUID — see
  **C10** below.
- **Ask, still open:**
  - `?search=` across name, specialty and bio.
  - `?ordering=rating | -rating | consultation_fee | -consultation_fee`.
  - `?is_general=true|false` (or a `category` field) so "Find a Clinician"
    can list general practitioners and "Find Specialists" can exclude
    them. Today the specialists screen shows nothing until a specialty is
    picked, because an unfiltered list can't exclude GPs.
  - More fields on each row: `full_name`, `rating_count`, `photo_url`,
    `next_available_slot` (ISO datetime or null), `languages`.
  - `GET /api/accounts/clinicians/{id}/` returning the same shape, so a
    clinician profile can be opened from a notification or a shared link.

### PT-C6. Specialties list

- **Today:** none. The specialist chips (Clinical Psychology,
  Physiotherapy, Psychiatry, Cardiology, Dermatology, Pediatrics,
  Gynaecology, Nutrition) are hard-coded in the app, and `specialty` is
  free text on the clinician, so "Cardiology" and "Cardiologist" would not
  match.
- **Ask:** `GET /api/specialties/` →
  `[{"id": 3, "name": "Cardiology", "clinician_count": 4}]`, and make
  `ClinicianProfile.specialty` choose from that list.

### PT-C7. Cancel with a reason; reschedule

- **Today:** `POST /api/appointments/{id}/cancel/` takes no body. There is
  no reschedule.
- **Ask:**
  - Optional `{"reason_code": "...", "reason": "free text"}` on cancel,
    stored with `cancelled_by` and `cancelled_at`, returned on the
    appointment.
  - `POST /api/appointments/{id}/reschedule/` with `{"scheduled_at": ...}`
    for `REQUESTED`/`CONFIRMED` scheduled appointments. Validates against
    the clinician's slots, sets the status back to `REQUESTED`, notifies
    the clinician.

### PT-C9. Replace an appointment in one step — ✅ Done

- **Was:** when a clinician declined or did not answer and the patient
  booked another, the app sent two requests: `POST /api/appointments/`,
  then `POST /api/appointments/{old}/cancel/`. If the second failed, the
  patient had two appointments.
- **Delivered:** an optional `replaces` field on `POST /api/appointments/`
  (`{"replaces": 32, ...}`), atomic — creates the new appointment,
  cancels the old one with reason `REPLACED`, ends any ringing call on
  it, and notifies the first clinician. The app sends this field and no
  longer cancels client-side.

### PT-C10. Expose the clinician's **user** UUID — new, P1

`POST /api/conversations/` (from **N10**, now live) takes `counterpart`,
a **user** UUID. The clinician directory and the appointment's nested
clinician both only expose `ClinicianProfile.id` (an int) — there is no
field anywhere a patient-facing response that carries the clinician's
`User.id`.

- **Effect today:** a patient can only reply inside a conversation a
  clinician already started. They cannot start one themselves, because
  there is nothing to pass as `counterpart`.
- **Ask:** add a `user_id` (UUID) field to `PublicClinicianSerializer`
  and `ClinicianBriefSerializer` (the one nested in
  `AppointmentSerializer`). Same shape clinicians already get for a
  patient's `patient_id` on the appointment — this is the mirror of that.

### PT-C11. Ordering (or a cursor) on conversation messages — new, P1

`GET /api/conversations/{id}/messages/` returns 20 per page, oldest
first, with no `?ordering=`. To show the newest messages when a thread is
opened, the app reads `count` from page 1, works out the last page, and
fetches the last two pages (not one, in case the newest message landed on
a fresh page by itself). That is three requests to open one thread.

- **Ask:** `?ordering=-created_at` (then the app reads page 1 and
  reverses it for display), or a `before`/`after` cursor so "give me the
  latest N" is a single request either way.

### PT-C12. Caller's name and the appointment id on INCOMING_CALL — new, P2

```python
body=f"{request.user.get_username()} is calling ({call.get_mode_display()}).",
payload={"call_id": call.id, "room_name": call.room_name, "mode": call.mode},
```

The body uses `get_username()`, which for an app-registered patient is an
email address, and for a clinician is `dr_adjei`-style — never the real
name **C1** added elsewhere. The payload also omits `appointment_id`, so
the app that just received a ring has to call `GET /api/calls/{id}/`
*and* list every appointment to find the matching one and its clinician's
real name, before it can show who is calling.

- **Ask:** use `get_full_name() or get_username()` in the body (matches
  how **C1** is applied everywhere else), and add `appointment_id` to the
  payload.

### PT-C8. Smaller ones

- `PATCH /api/accounts/me/` — confirm `phone` and `email` are writable and
  validated as unique; return a clear field error when taken.
- `POST /api/accounts/register/` — it accepts `role`. Please confirm a
  self-registered `CLINICIAN` cannot be booked until verified (the list
  filters on `VERIFIED`, so this looks right) and that `ADMIN`/`FACILITY`
  are rejected.
- Booking: `POST /api/appointments/` takes the clinician as `clinician`,
  but the response nests a clinician object under the same key, so
  `clinician_id` is the natural guess — and it is silently dropped, giving
  `{"clinician": ["Required for a SPECIFIC booking."]}`. Please reject
  unknown fields (or accept `clinician_id`) so a wrong client fails loudly.
- `.env.example`: add `10.0.2.2` (the Android emulator's alias for the host)
  to `DJANGO_ALLOWED_HOSTS`. Every Android developer hits `DisallowedHost`
  on first run without it.
- Booking: when an `ANY` booking finds no clinician, return a specific
  error code (e.g. `"code": "NO_CLINICIAN_AVAILABLE"`) so the app can
  offer other clinicians instead of showing raw text.

---

## Part 2 — New endpoints for screens the app already has

### PT-N1. Phone sign-up and login with OTP

- **Today:** `User.phone` exists. There is no OTP endpoint and login is by
  `username` only. The app's "I don't have an email" path says phone
  sign-in is coming soon. For email users the app registers with
  `username == email`.
- **Ask:**
  ```
  POST /api/auth/otp/request/   {"phone": "+233241234567"}
       → 200 {"expires_in": 300}                    (always 200; rate-limited)
  POST /api/auth/otp/verify/    {"phone": "...", "code": "123456"}
       → 200 {"access": "...", "refresh": "...", "is_new_user": true}
  ```
  A verified phone with no account creates a `PATIENT`. Also allow login
  by email or phone in `POST /api/auth/token/` so `username` stops being a
  visible concept. The SMS channel is a logging stub today; this needs the
  real provider (Hubtel or Twilio).

### PT-N2. Password reset and change password — backend ready, app pending

Same as clinician **N1**; one implementation serves both apps.

- **Delivered:** `POST /api/auth/password-reset/`,
  `/password-reset/confirm/`, `/password-change/`. Not wired up in the
  patient app yet — next on the list after this review.

### PT-N2a. Password-reset link is not reachable from a phone — new, P1

The reset email's link points at `FRONTEND_PASSWORD_RESET_URL`, which is
set to `http://localhost:4200` — a web dev server, not anything a phone
can open. A patient who requests a reset on their phone gets an email
they cannot act on from the device they're using.

- **Ask:** either a deep link the apps can register for
  (`carelite://reset-password?token=...`), or a hosted web page at a real
  domain that itself offers "open in the app" — either way,
  `localhost:4200` cannot be what ships.

### PT-N3. Logout — ✅ Done

Same as clinician **N2**. The app used to delete its tokens locally while
the refresh token stayed valid on the server.

- **Delivered:** `POST /api/auth/logout/` `{"refresh": "..."}` blacklists
  the token and clears the user's device tokens. The app now calls it on
  sign-out (best-effort — a local clear still happens even if the
  request fails, so being offline never traps someone in a signed-in
  state). Verified live: refreshing a blacklisted token now returns 401
  `token_not_valid`.

### PT-N4. Real push delivery

- **Today:** `/api/devices/` stores tokens, but `_deliver_push` in
  `notifications/channels.py` only logs. The patient app does not register
  a token yet.
- **Narrower than before:** the realtime socket (`ws/realtime/`, see
  **PT-S1**) now covers ringing, call status and message/notification
  badges while the app is **open** — a patient who answers can accept or
  decline the call live. What push still blocks is purely "the app is
  closed or backgrounded": no ring, no badge, nothing, until it's
  reopened.
- **Ask:** send through FCM (which also covers APNs). For `INCOMING_CALL`
  send a **data-only, high-priority** message with `call_id`,
  `appointment_id`, `caller_name`, so the phone can show a ringing screen
  while the app is closed. Remove tokens FCM reports as invalid.
- **App side:** needs a Firebase project from the product owner, then
  `firebase_messaging` and token registration at login.

### PT-S1. WebSocket token travels in the query string — new, P3

`ws/realtime/?token=<access>` is how both apps authenticate the socket
(browsers cannot set a header on the WebSocket handshake, so this is a
reasonable choice — flagging it as a trade-off to confirm, not a bug).
The access token then sits in plain text in Daphne's request logs, any
reverse proxy's access log, and browser devtools history for the lifetime
of log retention — worse than a header, which proxies don't log by
default.

- **Ask, not urgent:** consider a short-lived one-time ticket instead —
  an authenticated `POST /api/auth/ws-ticket/` returning a token good for
  one connection attempt within, say, 10 seconds — so what ends up in
  logs is useless after the handshake completes. Low priority: the
  access token already has a short lifetime and this is defense in depth,
  not an open hole.

### PT-N5. Real call media — ✅ Done, with a gap

Same as clinician **N5**. `join_token` used to be `"stub-token-<room>"`.

- **Delivered:** Daily.co rooms. `CallSessionSerializer` nests a `room`
  object with `room_url` when `DAILY_API_KEY` is configured; the app
  opens it in-browser once a call is accepted ("Join video"). Ring,
  accept, decline and end were already real.
- **Gap:** without `DAILY_API_KEY` set, `room_url` stays null and the
  call screen can only say "video is not set up on the server yet" —
  please confirm the key is set in every environment the app will be
  demoed or tested against, since this is otherwise silent.

### PT-N6. "Everything of mine" lists

- **Today:** prescriptions and investigations can only be read per
  consultation. Opening one record costs four requests (summary, notes,
  prescriptions, investigations), and there is no way to show "my active
  prescriptions" or "tests waiting for me" on Home.
- **Ask:** `GET /api/prescriptions/` and `GET /api/investigations/`,
  scoped to the signed-in patient, paginated, with `?status=` and
  `?consultation=`. (The clinician document asks for the same routes
  scoped to a facility operator in **L1** — one view, scoped by role.)

### PT-N7. Rate a clinician

- **Today:** `ClinicianProfile.rating` is a decimal with the help text
  "Average patient rating", but nothing writes it except the admin.
- **Ask:**
  ```
  POST /api/appointments/{id}/review/   {"rating": 5, "comment": "..."}
  GET  /api/accounts/clinicians/{id}/reviews/
  ```
  Patient only, `COMPLETED` appointments only, one per appointment.
  Recalculate `rating` and a new `rating_count` on save.

### PT-N8. Profile photo

- **Ask:** `photo` (image) on `User`, `PATCH /api/accounts/me/` as
  multipart, `photo_url` on user and clinician responses. The clinician
  app needs the same field.

### PT-N9. Insurance

- **Today:** nothing.
- **Ask:** on `PatientProfile`: `insurance_type` (`NONE | PUBLIC |
  PRIVATE`), `insurer` (FK), `member_number`, `expiry_date`; and
  `GET /api/insurers/` so the private-insurer list is not hard-coded
  (NHIS as the one public entry).

### PT-N10. Messaging — ✅ Done

Same as clinician **N7**. The Messages tab used to be an honest stub in
both apps.

- **Delivered:** a `messaging` app — `GET/POST /api/conversations/`,
  `GET/POST /api/conversations/{id}/messages/`,
  `GET /api/conversations/unread-count/`, gated on a shared appointment
  (`_relationship_exists`). New messages also fire a `NEW_MESSAGE`
  notification and a `message` event on the realtime socket. The app's
  inbox, threads and unread badge are all built on this — see **C10**
  and **C11** for the two rough edges found while building it.

### PT-N11. Vitals history — backend ready, app pending

Same model as clinician **N3**.

- **Delivered:** `vitals` app —
  `GET/POST /api/consultations/{id}/vitals/` and
  `GET /api/patients/{id}/vitals/` (a patient may read their own trend).
  Not wired up in the app yet; next after password change/reset.

### PT-N12. Record access / consent — backend ready, app pending

- **Delivered:** an `access` app —
  `GET/POST /api/access-requests/`,
  `POST /api/access-requests/{id}/approve|decline|revoke/`,
  `GET /api/patients/`, `GET /api/patients/{id}/`. Approving/declining
  raises a `GENERIC` notification with `payload.access_request_id`. Not
  wired up in the app yet — it would add a "Who can see my record" screen
  reading this list and calling the action endpoint.

### PT-N13. Result files and PDF export

- **Today:** `InvestigationResult.file` comes back as a media path. A plain
  `GET` on it carries no JWT, so the app cannot fetch it and Records says
  "ask your clinician for a copy". Files are on local disk, with no cloud
  storage yet. The backend PRD lists "download/share prescription or lab
  result as PDF" as an acceptance criterion; it is not built.
- **Ask:**
  - Serve result files through an authenticated endpoint, or return a
    short-lived signed URL.
  - `GET /api/prescriptions/{id}/pdf/` and `GET /api/investigations/{id}/pdf/`.
  - Say where uploads will live in production (S3 or similar). The profile
    photo in **PT-N8** depends on the same answer.

---

## Part 3 — Labs and pharmacy, patient side

The full nine-step loop and the facility side are in the clinician
document (**L1–L4**). What the patient app needs from it:

### PT-L1. Accept or decline an ordered test

Same as clinician **L3**.

- **Today:** `REQUESTED → ACCEPTED (by facility) → SAMPLE_DONE →
  RESULT_UPLOADED`. The patient is never asked, and the patient is not
  notified that a test was ordered.
- **Ask:**
  ```
  POST /api/investigations/{id}/respond/
       {"decision": "ACCEPT", "facility_id": 4}     // or "DECLINE", "reason"
  GET  /api/investigations/{id}/facilities/?lat=&lng=
       → ranked labs that offer this test, with distance_km and price
  ```
  New statuses `AWAITING_PATIENT` (initial) and `DECLINED`. Accepting
  records the patient's consent to share name, age and phone with that
  facility (clinician **L2**) with a timestamp.

### PT-L2. Pickup or delivery for a prescription

Same as clinician **L4**.

- **Ask:**
  ```
  POST /api/prescriptions/{id}/fulfilment/
       {"method": "PICKUP"}
       {"method": "DELIVERY", "address": "...", "lat": 5.56, "lng": -0.20,
        "phone": "+233..."}
  ```
  and on the prescription: `status` (`SIGNED | SENT_TO_PHARMACY |
  READY | OUT_FOR_DELIVERY | COLLECTED | DELIVERED | CANCELLED`),
  `fulfilment_method`, `total_price`.

### PT-L3. Directions and tap-to-call

No backend change needed for the data: investigation and prescription
responses already nest the full facility (`name, address, phone, lat,
lng, operating_hours`), and the app now shows Directions and Call from it.
The seeded facilities have no `phone`, so Call is hidden for them — please
make `phone` required when a facility is onboarded. Two small asks:

- Add `distance_km` to the nested facility when the patient's location is
  known.
- The nested facility also includes the whole `services` and `inventory`
  lists. A patient does not need a pharmacy's full stock list on every
  prescription — please use a slim serializer here.

### PT-L4. Keep the patient's location current

`POST /api/appointments/{id}/location/` exists but can only be called for
a specific appointment before it starts. Lab and pharmacy matching happens
later.

- **Ask:** let the patient update `last_known_lat/lng` at any time through
  `PATCH /api/accounts/me/patient-profile/` (the fields are already on the
  serializer — please confirm they are writable and used by the matcher
  as the fallback, as in clinician **C6**).

---

## Part 4 — Payments

Nothing exists (no payment, escrow or wallet model). The shared foundation
is clinician **P1**; the patient is the paying side of all of it.

### PT-P1. Paying

- **Ask (patient side of P1):**
  ```
  POST /api/payments/initiate/
       {"purpose": "CONSULTATION" | "INVESTIGATION" | "PRESCRIPTION",
        "object_id": 12, "method": "MOMO", "phone": "+233..."}
       → {"payment_id": 7, "status": "PENDING", "amount": "120.00",
          "currency": "GHS", "checkout_url": null}
  GET  /api/payments/{id}/                → status for polling
  GET  /api/payments/                     → my payment history
  ```
  plus `payment_status` (`UNPAID | PENDING | PAID | REFUNDED`) and
  `amount` on appointments, investigations and prescriptions, and a
  `price` on each so the patient sees it before accepting.
- A provider webhook should move the status; the app only polls.

### PT-P2. Featured clinicians

Same as clinician **P4**. Patient side: `is_featured` on each row of
`GET /api/accounts/clinicians/`, with ordering `-is_featured, -rating`
applied **server-side**. The app shows a "Featured" label so paid
placement is distinguishable from rating.

---

## Part 5 — In-person visits

Not built; every appointment is implicitly virtual. Full reasoning is in
`docs/PRODUCT_PATHWAY.md`.

- **PT-V1. Clinician location** captured at onboarding: `region` / `area`
  (matches how clinicians are being registered, starting in the North)
  and optional `lat` / `lng`.
- **PT-V2. `visit_type: VIRTUAL | IN_PERSON`** on `Appointment`, separate
  from `mode`, plus an optional `follows_appointment` link so an
  in-person visit can continue a virtual one.
- **PT-V3. "Close to me"** — `?near_lat=&near_lng=&max_km=` (or
  `?region=`) on the clinician list, returning `distance_km` and
  **excluding** anyone outside the radius. `facilities/matching.py`
  already does this for facilities.

---

## Part 6 — Notifications the patient should receive

Same mechanism as clinician **T1**, now with a delivery half that works:
every `notify()` call also pushes over `ws/realtime/` to whichever device
has it open (`push_to_user`), so a type that exists reaches the app
immediately rather than waiting for the next poll. Types the patient app
would handle, with the payload it needs to open the right screen:

| Type | When | Payload |
|---|---|---|
| `APPOINTMENT_CONFIRMED` | clinician confirms | `appointment_id` |
| `APPOINTMENT_CANCELLED` | clinician cancels | `appointment_id`, `reason` |
| `APPOINTMENT_REMINDER` | 15 min before a scheduled time | `appointment_id` |
| `INCOMING_CALL` (exists) | clinician rings | `call_id`, `appointment_id`¹ |
| `CALL_MISSED` | call not answered | `appointment_id` |
| `SUMMARY_READY` | consultation completed | `consultation_id` |
| `TEST_ORDERED` | clinician orders a test | `investigation_id`, `consultation_id` |
| `TEST_ACCEPTED_BY_LAB` | lab accepts | `investigation_id` |
| `RESULT_READY` (exists) | result uploaded | `investigation_id`, `consultation_id` |
| `PRESCRIPTION_READY` | prescription signed | `prescription_id`, `consultation_id` |
| `PRESCRIPTION_STATUS` | ready / out for delivery / delivered | `prescription_id`, `status` |
| `REFERRAL_CREATED` | clinician refers the patient | `referral_id`, `consultation_id` |
| `PAYMENT` (exists, unused) | payment succeeded / failed / refunded | `payment_id` |
| `NEW_MESSAGE` (exists) | a message arrives | `conversation_id` |
| `GENERIC` (exists) | e.g. an access request | `access_request_id` or type-specific |

¹ Wanted, not yet sent — see **PT-C12**.

Unknown types fall back to a generic row in the app, so new ones can be
added without an app release. Please always include `consultation_id`
alongside an investigation or prescription id — the app can only load
those through their consultation until **PT-N6** exists.

---

## Appendix A — What the patient app uses today

In use and working:

- Auth: `POST /api/auth/token/`, `/token/refresh/`,
  `/api/auth/logout/`; `POST /api/accounts/register/`;
  `GET/PATCH /api/accounts/me/`
- Profile: `GET/PATCH /api/accounts/me/patient-profile/`
  (`date_of_birth`, `sex`, `blood_group`)
- Clinicians: `GET /api/accounts/clinicians/` (`?specialty=`,
  `?online=true`); `GET …/{id}/slots/`
- Appointments: `GET/POST /api/appointments/` (`?status=`, `?from=&to=`,
  `replaces`); `POST …/{id}/cancel/`; `GET/POST …/{id}/precall/`;
  `POST …/{id}/call/`
- Calls: `GET /api/calls/{id}/`; `POST …/accept/`, `/decline/`, `/end/`
- Records: `GET /api/consultations/`, `…/{id}/`, `…/{id}/summary/`,
  `…/notes/`, `…/prescriptions/`, `…/investigations/`
- Facilities: `GET /api/facilities/`, `POST /api/match/`
- Notifications: `GET /api/notifications/` (`?unread=true`),
  `GET /api/notifications/unread-count/`, `POST …/{id}/read/`,
  `POST …/read-all/`
- Messaging: `GET/POST /api/conversations/`,
  `GET/POST /api/conversations/{id}/messages/`,
  `GET /api/conversations/unread-count/`
- Realtime: `ws/realtime/?token=<access>` — one socket per session,
  reconnects with backoff, re-authenticates on close code 4001

Exists but not used by the patient app yet: `/api/auth/password-reset/`,
`/password-reset/confirm/`, `/password-change/` (**PT-N2**);
`/api/patients/{id}/vitals/` (**PT-N11**); `/api/access-requests/`
and `/api/patients/` (**PT-N12**); `/api/devices/` (waiting on Firebase,
**PT-N4**); `/api/appointments/{id}/location/`;
`/api/auth/token/verify/`.

Things the app relies on that are easy to break:

- Login field is `username`; the app registers with `username == email`.
- Booking a named clinician posts `clinician` (not `clinician_id`).
- Statuses are uppercase: `REQUESTED, CONFIRMED, IN_PROGRESS, COMPLETED,
  CANCELLED`.
- `clinician` on an appointment can be null.
- Summary returns `404` until the appointment is completed.
- Ending a call twice returns `400` with a bare list body.
- A non-patient account is refused at sign-in by the app, based on `role`
  from `/api/accounts/me/`.
- "Profile complete" is derived: a patient is complete once
  `date_of_birth` is set.
- Lists are page-number paginated, 20 per page. The patient app reads the
  first page only for appointments and notifications.

## Appendix B — Open product questions

These need a decision before the backend work can be specified further:

1. **When is a consultation paid for?** Proposal in
   `docs/PRODUCT_PATHWAY.md`: charge into escrow at confirmation,
   release on `COMPLETED`, auto-refund if the clinician cancels or never
   joins, short dispute window if a call drops mid-way.
2. **Does insurance change what the patient pays**, or is it only
   recorded for now?
3. **One `FACILITY` role or separate lab and pharmacist roles?**
   `Facility.type` already distinguishes them.
4. **Patient data shared with labs and pharmacies** (name, age, phone) is
   personal health data under Ghana's Data Protection Act, 2012. The
   consent step in PT-L1 is the proposed basis; worth a legal check.
5. **Clinician location precision** for in-person visits: region tag,
   coordinates, or both.
