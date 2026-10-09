# CareLite backend — requests from the patient app

Companion to the clinician app's `BACKEND_REQUESTS.md`, which you already
have. This one covers what the **patient** app (`carelite_app`) needs.
Where a request is the same change as one in the clinician document, it is
marked "same as clinician Xn" and only the patient-side detail is added
here — build it once.

Checked against the backend source dated 9 Sep 2026 (9 local apps, 49
routes) on 9 Oct 2026. IDs in this document start with `PT-`.

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

Size: S = under a day, M = a few days, L = a week or more.

| Pri | ID | Request | Size | Same as clinician | Unblocks in the patient app |
|---|---|---|---|---|---|
| P0 | PT-B1 | `unread-count` counts each event once per channel | S | B3 | App works around it with a heavier request |
| P0 | PT-B2 | Patient is not told when a booking is confirmed or cancelled | S | T1 | Patient has to keep opening Appointments |
| P1 | PT-C1 | Names on user, clinician and appointment responses | S | C1 | Full name on Complete Profile; real doctor names |
| P1 | PT-C2 | Emergency contact on `PatientProfile` | S | — | Complete Profile field that is not saved today |
| P1 | PT-C3 | Filters and ordering on `GET /api/appointments/` | S | C3 | Upcoming / Past beyond 20 rows |
| P1 | PT-C4 | `consultation_id` and `active_call_id` on appointments | S | C2 | Join Call; open the record from an appointment |
| P1 | PT-C5 | Clinician list: search, more fields, detail endpoint | S–M | — | Find a Clinician, clinician profile |
| P1 | PT-C6 | Specialties list | S | — | Specialist chips are hard-coded |
| P1 | PT-C7 | Cancel with a reason; reschedule | S–M | — | Appointments |
| P1 | PT-C9 | Replace an appointment in one step | S | — | Switching clinician after an unanswered call |
| P1 | PT-N1 | Phone sign-up and login with OTP | M | — | "I don't have an email" path |
| P1 | PT-N2 | Password reset and change password | M | N1 | No way to recover an account |
| P1 | PT-N3 | Logout (refresh-token blacklist) | S | N2 | Sign out |
| P2 | PT-N4 | Real push delivery (FCM) | M | — | Incoming call when the app is closed |
| P2 | PT-N5 | Real call media | M–L | N5 | Audio and video |
| P2 | PT-N6 | "All my prescriptions / tests" lists | S | — | Records without 4 calls per consultation |
| P2 | PT-N7 | Rate a clinician | M | — | Ratings are admin-set today |
| P2 | PT-N8 | Profile photo upload | S | — | Complete Profile, Profile |
| P2 | PT-N9 | Insurance on `PatientProfile` | S–M | — | Profile, onboarding |
| P2 | PT-N13 | Authenticated result-file download; PDF export | S–M | — | Records says "ask your clinician for a copy" |
| P2 | PT-L1 | Patient accepts or declines an ordered test | M | L3 | Consent step |
| P2 | PT-L2 | Pickup or delivery for a prescription | M | L4 | Pharmacy choice |
| P3 | PT-N10 | Messaging | L | N7 | Messages tab |
| P3 | PT-N11 | Vitals history | M | N3 | Records |
| P3 | PT-N12 | Record access / consent | M | — | Who can see my record |
| P3 | PT-P1 | Pay for a consultation, test, prescription | L | P1 | Everything paid |
| P3 | PT-P2 | Featured clinicians first | S | P4 | "Featured" label |
| P3 | PT-V1–V3 | In-person visits | M–L | — | "Close to me" filter |

Suggested order: Part 0 → PT-C1 to C7 → PT-N1 to N3 → PT-N4, N5 → Part 3 →
payments.

---

## Part 0 — Bugs and gaps in existing endpoints

### PT-B1. `GET /api/notifications/unread-count/` over-counts

Same as clinician **B3**. `notify()` writes one row per channel (`IN_APP`,
`SMS`, `PUSH`), and the count includes all of them, so one incoming call
counts as 3.

- **Patient app today:** it no longer calls this endpoint. It fetches
  `GET /api/notifications/?unread=true` and counts the `IN_APP` rows itself,
  and filters the list the same way. That is correct but heavier, and it
  undercounts past 20 unread (one page).
- **Ask:** count `IN_APP` rows only. Ideally `GET /api/notifications/`
  defaults to `channel=IN_APP` too. The app then goes back to the cheap
  endpoint.

### PT-B2. The patient is not told what happens to their booking

`notify()` is called in exactly three places: a new booking (to the
clinician), an incoming call, and a result upload (to the patient).
Nothing is sent to the patient when a clinician **confirms**, **cancels**,
**starts** or **completes** an appointment, orders a test, writes a
prescription, or assigns a lab or pharmacy.

- **Ask:** see [Part 6](#part-6--notifications-the-patient-should-receive).
  The two that matter most now are `APPOINTMENT_CONFIRMED` and
  `APPOINTMENT_CANCELLED`.

---

## Part 1 — Small changes to existing endpoints

### PT-C1. Names

Same as clinician **C1**. `first_name` and `last_name` already exist on
`AbstractUser`; no serializer exposes them.

- **Ask:**
  - `UserSerializer` and `RegisterSerializer`: add `first_name`,
    `last_name` (writable), and a read-only `full_name`.
  - `PublicClinicianSerializer` and the clinician nested in
    `AppointmentSerializer`: add `full_name`.
  - Consultation list: add `clinician_name` next to `clinician_username`.
- **Why:** Complete Profile collects a full name and has nowhere to send
  it. Clinicians appear as "Dr. Adjei" only because the app reformats
  `dr_adjei`. For accounts registered through the app, `username` is the
  person's email, so that is what other users would see.

### PT-C2. Emergency contact

- **Today:** `PatientProfile` has `emergency_flag` (boolean, "needs faster
  attention") and nothing else.
- **Ask:** `emergency_contact_name`, `emergency_contact_phone`,
  `emergency_contact_relationship` on `PatientProfile`, patient-writable.
  Leave `emergency_flag` as it is.

### PT-C3. Filters on `GET /api/appointments/`

Same as clinician **C3**. The patient app reads one page of 20 and splits
Upcoming / Past on the phone, so a patient's 21st appointment is not shown.

- **Ask:** `?status=` (comma list), `?from=&to=`, `?ordering=`; default
  ordering `-created_at`.

### PT-C4. More fields on the appointment response

Same as clinician **C2**: `consultation_id` (null until started) and
`active_call_id` (id of a `RINGING`/`ACCEPTED` call, else null).

- **Why, patient side:** when the clinician rings and the patient missed
  the notification, the app has no way to ask "is there a live call for
  this appointment?". And from a past appointment there is no link to its
  consultation record.

### PT-C5. Clinician directory

- **Today:** `GET /api/accounts/clinicians/` supports `?specialty=`
  (contains) and `?online=true`, ordered `-rating, username`. Each row is
  `id, username, specialty, bio, years_experience, consultation_fee,
  is_online, rating`. There is no detail endpoint.
- **Ask:**
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

### PT-C9. Replace an appointment in one step

- **Today:** when a clinician declines or does not answer and the patient
  books another, the app sends two requests: `POST /api/appointments/`,
  then `POST /api/appointments/{old}/cancel/`. If the second fails, the
  patient has two appointments.
- **Ask:** an optional `replaces` field on `POST /api/appointments/`
  (`{"replaces": 32, ...}`). In one transaction: create the new
  appointment, cancel the old one with reason `REPLACED`, end any ringing
  call on it, and notify the first clinician. Return the new appointment.

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

### PT-N2. Password reset and change password

Same as clinician **N1**; one implementation serves both apps.

### PT-N3. Logout

Same as clinician **N2**. The app deletes its tokens locally; the refresh
token stays valid on the server.

### PT-N4. Real push delivery

- **Today:** `/api/devices/` stores tokens, but `_deliver_push` in
  `notifications/channels.py` only logs. The patient app does not register
  a token yet.
- **Ask:** send through FCM (which also covers APNs). For `INCOMING_CALL`
  send a **data-only, high-priority** message with `call_id`,
  `appointment_id`, `caller_name`, so the phone can show a ringing screen
  while the app is closed. Remove tokens FCM reports as invalid.
- **App side:** needs a Firebase project from the product owner, then
  `firebase_messaging` and token registration at login.

### PT-N5. Real call media

Same as clinician **N5**. `join_token` is `"stub-token-<room>"`. Ring,
accept, decline and end are real; nothing carries audio or video. Please
pick the provider (LiveKit, Agora, Twilio, Daily) — it decides which SDK
both apps add.

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

### PT-N10. Messaging

Same as clinician **N7**. The Messages tab is an honest stub in both apps.

### PT-N11. Vitals history

Same model as clinician **N3**. Patient side:
`GET /api/accounts/me/vitals/` (read-only list, newest first) for a trend
on Records.

### PT-N12. Record access / consent

An `access` app (access requests, patient approve/revoke) was seen on a
newer commit of the repository but is not in this checkout's
`INSTALLED_APPS`. If it has landed, please share the commit and its
endpoints; the patient app would add a "Who can see my record" screen.

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

Same mechanism as clinician **T1**. Types the patient app would handle,
with the payload it needs to open the right screen:

| Type | When | Payload |
|---|---|---|
| `APPOINTMENT_CONFIRMED` | clinician confirms | `appointment_id` |
| `APPOINTMENT_CANCELLED` | clinician cancels | `appointment_id`, `reason` |
| `APPOINTMENT_REMINDER` | 15 min before a scheduled time | `appointment_id` |
| `INCOMING_CALL` (exists) | clinician rings | `call_id`, `appointment_id` |
| `CALL_MISSED` | call not answered | `appointment_id` |
| `SUMMARY_READY` | consultation completed | `consultation_id` |
| `TEST_ORDERED` | clinician orders a test | `investigation_id`, `consultation_id` |
| `TEST_ACCEPTED_BY_LAB` | lab accepts | `investigation_id` |
| `RESULT_READY` (exists) | result uploaded | `investigation_id`, `consultation_id` |
| `PRESCRIPTION_READY` | prescription signed | `prescription_id`, `consultation_id` |
| `PRESCRIPTION_STATUS` | ready / out for delivery / delivered | `prescription_id`, `status` |
| `REFERRAL_CREATED` | clinician refers the patient | `referral_id`, `consultation_id` |
| `PAYMENT` (exists, unused) | payment succeeded / failed / refunded | `payment_id` |

Unknown types fall back to a generic row in the app, so new ones can be
added without an app release. Please always include `consultation_id`
alongside an investigation or prescription id — the app can only load
those through their consultation until **PT-N6** exists.

---

## Appendix A — What the patient app uses today

In use and working:

- Auth: `POST /api/auth/token/`, `/token/refresh/`;
  `POST /api/accounts/register/`; `GET/PATCH /api/accounts/me/`
- Profile: `GET/PATCH /api/accounts/me/patient-profile/`
  (`date_of_birth`, `sex`, `blood_group`)
- Clinicians: `GET /api/accounts/clinicians/` (`?specialty=`,
  `?online=true`); `GET …/{id}/slots/`
- Appointments: `GET/POST /api/appointments/`; `POST …/{id}/cancel/`;
  `GET/POST …/{id}/precall/`; `POST …/{id}/call/`
- Calls: `GET /api/calls/{id}/`; `POST …/end/`
- Records: `GET /api/consultations/`, `…/{id}/`, `…/{id}/summary/`,
  `…/notes/`, `…/prescriptions/`, `…/investigations/`
- Facilities: `GET /api/facilities/`, `POST /api/match/`
- Notifications: `GET /api/notifications/` (`?unread=true`),
  `POST …/{id}/read/`, `POST …/read-all/`

Exists but not used by the patient app: `/api/notifications/unread-count/`
(see **PT-B1**), `/api/devices/` (waiting on Firebase), `/api/appointments/{id}/location/`, `/api/auth/token/verify/`,
`/api/calls/{id}/accept/` and `/decline/` (the patient app can start a call
but cannot yet answer one the clinician starts).

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
