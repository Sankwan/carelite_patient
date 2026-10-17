# Backend review — patient app and CareLite Pro, 16 Oct 2026

For the backend developer. One list of everything both apps need from the
backend before an APK goes to stakeholders, checked against the code rather
than against earlier docs.

**Checked against:** `campofo/carelite` `main` at `58ad5f9` (127 backend
tests passing), the patient app (`carelite_app`) and CareLite Pro
(`carelite_clinician`). Every "today" statement below was verified in the
backend source on that commit; file and line references are in the
appendix.

**Earlier documents this replaces as the working list** (they stay as the
detailed record, with the same IDs):

- Patient app: `carelite_app/docs/BACKEND_REQUESTS_PATIENT.md` (`PT-` IDs)
- CareLite Pro: `carelite_clinician/docs/BACKEND_REQUESTS.md` (`B/C/N/L/P/T`
  IDs) and `SPEC_CARE_ORDER_FLOW.md` (the agreed v2 test-order flow)
- New items found in this review use `R-` IDs.

## Summary

| Tier | What it means | Items |
|---|---|---|
| **P0** | Without these, a stakeholder can't install the APK and see the core journey work | R1, PT-B3, R2, R3, L1, v2 stage 1, R4, PT-B2 |
| **P1** | Needed before real patients use it | R13–R18 (results and record access), Push, payments, PT-N2a, PT-C10, PT-C12, PT-C7, PT-C11, L2, L4, N4, PT-N1, PT-V1–V3, R5, reroute cron |
| **P2** | Later | Rating, photo, NHIS, reschedule, clinician sign-up, featured listings, PT-S1, PT-N6, PT-C2 |

The single biggest item is **v2 stage 1** (test orders). Every lab and
imaging screen in CareLite Pro runs on sample data until it exists, and the
patient app has no accept/pay step to build against.

---

## P0 — before an APK can be shared

### R1. Hosted backend — deployed, but empty

**Done:** `https://carelite.onrender.com` is up over HTTPS (Daphne behind
Cloudflare). Its schema matches `58ad5f9` exactly (94 operations), and the
realtime socket accepts an authenticated `wss` connection (`101`).

**Still open:**
- **No demo data.** The database has 1 clinician (`fixed_clinician`), 3
  appointments, **0 facilities** and no `FACILITY` accounts. None of the
  `seed_demo` users (`kofi`, `dr_adjei`, `op_lab`, …) exist. With no
  facilities, lab matching returns nothing, so the lab half of the journey
  can't be tested here. Please run `seed_demo` (or an equivalent with
  real pilot facilities in the Northern Region) and send one confirmed list
  of accounts and passwords for every role.
- `fixed_patient` / `fixed_clinician` exist, but `accounts/startup.py`
  only seeds them under `runserver`, so they won't come back on a fresh
  production database.
- **Free-tier sleep:** if this instance sleeps when idle, the first request
  can take 30–60 s, and both apps time out after 15–20 s. Keep it awake
  for stakeholder testing, or tell us and the apps will retry on wake.

### PT-B3. `demo.sqlite3` is behind its migrations — still open

**Today:** a copy of the committed `demo.sqlite3` has 10 unapplied
migrations (accounts 0007–0009, appointments 0004, calls 0003,
notifications 0002–0003, and others), so `migrate` on a fresh clone fails.
It also holds 15 leftover `live_test_…` patient accounts from earlier test
runs.

**Ask:** remove it from the repo and document `migrate && seed_demo`, or
regenerate it after every migration. Either way, drop the `live_test_…`
accounts from the seed.

### R2. Real audio/video in calls — `DAILY_API_KEY` not set

**Today:** rooms are created only when `DAILY_API_KEY` is set
(`calls/views.py`). It isn't set, so both apps can ring, answer and end a
call, but the call carries no audio or video. Both apps already open the
room when a URL is returned.

**Ask:** set `DAILY_API_KEY` on the shared server.

### R3. Uploaded files are never served

**Today:** `MEDIA_URL = "/media/"` is set (`config/settings.py:167`), but
no route serves it, so a lab result with an attached file can't be opened
by the clinician or the patient.

**Ask:** serve media (object storage such as S3 or GCS in production, with
signed URLs, since these are health records), and return absolute file URLs
in `InvestigationResultSerializer.file`.

### L1. Facility identity on `/api/accounts/me/` — still open

**Today:** a `FACILITY` login can't tell which facility it operates or
whether it's a lab or a pharmacy. `FacilitySerializer` doesn't expose
`operator` either, so the app can't work it out. As a result `op_pharm`
lands on the lab screens.

**Ask:** add `facility: {id, name, type}` to `/api/accounts/me/` for
`FACILITY` users.

### v2 stage 1. The test-order flow — not started

**Today** (`investigations/models.py`, `views.py`):
- Statuses are `REQUESTED → ACCEPTED → SAMPLE_DONE → RESULT_UPLOADED`
  (plus `CANCELLED`). There is no patient step at all.
- The clinician assigns a facility, and the facility can act on the order
  immediately. The agreed decision is that the facility sees nothing until
  the patient has paid.
- **A facility cannot list its orders.** Investigations are reachable only
  by id or per consultation, so a lab has no queue. This is why every lab
  screen in CareLite Pro uses sample data.
- No prices, no visit code, no per-item decline, no clinician review step.

**Ask:** stage 1 of `SPEC_CARE_ORDER_FLOW.md`: orders and items, the
status flow (`AWAITING_PATIENT → AWAITING_PAYMENT → PAID → CONFIRMED →
CHECKED_IN → SAMPLE_DONE → RESULT_UPLOADED → REVIEWED`, plus
`DECLINED / EXPIRED / REJECTED_BY_FACILITY / CANCELLED`), facility prices,
`GET /api/facility/orders/`, the patient endpoints (decline,
choose-facility, pay) and the clinician review endpoint. The spec's
endpoint list is the contract both apps will build against.

Payments can be in the provider's test mode for this stage (see P1).

### R4. Results reach the patient before the clinician — contradicts decision 4

**Today:** uploading a result notifies the patient immediately
(`investigations/views.py:231`, `RESULT_READY`), and the patient app shows
it in Records.

**Agreed (spec decision 4):** results go to the clinician first. The
patient sees the result once the clinician marks it `REVIEWED`, or
automatically after the release window (48 h proposed).

**Ask:** hold the patient's `RESULT_READY` and the result content until
`REVIEWED` or auto-release. This lands naturally with v2 stage 1. The full
rule, including sensitive results, is in *Results, records and patient
access* (R13–R18).

### PT-B2. The patient is never told what happened to their booking — still open

**Today:** notifications are sent from exactly seven places: new booking
(to the clinician), one-step replacement, incoming call, result upload
(×2), access request, new message. Nothing is sent when a clinician
**confirms**, **starts** or **completes** an appointment, when either side
**cancels** normally (`appointments/views.py:210` sends nothing), or when a
test is ordered, a prescription is written or a facility is assigned.

In an end-to-end run, a patient books and then has to keep refreshing to
find out whether the clinician accepted.

**Ask:** at minimum `APPOINTMENT_CONFIRMED` and `APPOINTMENT_CANCELLED`
(to the other party) with `{appointment_id}` in the payload. The rest are
listed in `BACKEND_REQUESTS_PATIENT.md` Part 6 and CareLite Pro's T1.

---

## P1 — before real patients

| ID | Today | Ask |
|---|---|---|
| **Push (PT-N4)** | `POST /api/devices/` stores tokens, but the PUSH channel only writes a log line (`notifications/channels.py:31`). A call or message reaches a phone only while the app is open. | FCM delivery through one Firebase project shared by both apps; send the service-account setup so both apps can add `google-services.json`. |
| **Payments (P1–P4, PT-P1)** | No payment, escrow, wallet or price model anywhere. The patient app says "You are not charged now". | Provider choice (Hubtel, Paystack or MoMo), test mode first, escrow and release, commissions. Blocked on the open decisions below. |
| **PT-N2a** | The reset email links to `http://localhost:4200/reset-password` (`config/settings.py:220`). | Point `FRONTEND_PASSWORD_RESET_URL` at the hosted web build. |
| **PT-C10** | Neither the clinician list nor the appointment's nested clinician exposes the clinician's **user** id, and `POST /api/conversations/` needs it as `counterpart`. A patient can only reply, never start a chat. | Add `user_id` to `PublicClinicianSerializer` and `ClinicianBriefSerializer`. |
| **PT-C12** | `INCOMING_CALL` payload is `{call_id, room_name, mode}`; the body uses the username ("kofi is calling"). | Add `appointment_id` and `caller_name` (full name), and use the full name in the body. |
| **PT-C7** | `cancellation_reason` exists, but `POST /cancel/` ignores the request body and notifies no one. | Accept `{"reason": …}` from both roles, and notify the other party (see PT-B2). |
| **PT-C11** | Messages come oldest first with no ordering parameter, so the apps load whole threads. | `?ordering=-created_at` or a cursor. |
| **L2** | A facility has no patient contact block. | Patient name, age and phone for the facility after payment (part of v2). |
| **L4 / PT-L2** | A prescription has no status and no pickup/delivery choice. | Status and fulfilment method on the same pattern as v2 orders. |
| **N4** | No test catalogue; CareLite Pro uses a demo list. | `GET /api/tests/?q=`. |
| **PT-N1** | Email and password only. The rollout starts in Northern Ghana, where many patients won't have an email address. | Phone sign-up and login with OTP. |
| **PT-V1–V3** | `ClinicianProfile` has no location, and `Appointment.mode` only means scheduled or on demand. "Close to me" and in-person visits can't be built. | Clinician region or area (and optional lat/lng), a visit type on the appointment, and a distance or region filter on the clinician list. |
| **R5. Clinician detail** — new | There is no `GET /api/accounts/clinicians/{id}/`, so the patient app can't open a clinician from a link or a notification. | A detail endpoint returning the public clinician card. |
| **PT-C6** | No specialties list; the patient app hard-codes the chips. | `GET /api/specialties/`. |
| **Reroute cron** | `reroute_stale_appointments` only runs if scheduled; unconfirmed whether it is. | Schedule it on the shared server. |
| **R6. Usernames in notification text** — new | The access-request notification reads "Dr dr_adjei is requesting access to your records" (`access/views.py:59`); `INCOMING_CALL` has the same problem (PT-C12). | Use `get_full_name()` with the username as fallback, everywhere a person is named in a title or body. |
| **R8. Accepting a call doesn't start the consultation** — found in the end-to-end test | After a call is ACCEPTED the appointment stays CONFIRMED with no consultation, so the clinician can't record vitals or notes during the call; they must hang up and press Start. | Accepting the call (or the first call on an appointment) moves it to IN_PROGRESS and creates the consultation. |
| **R9. Facility matching has no distance limit** — found in the end-to-end test | A patient in Tamale was offered Circle Diagnostics in Accra, 431.66 km away, and the same for the pharmacy. The seed has no Northern Region facilities. | A maximum radius (or region match) on lab and pharmacy matching, returning "none nearby" instead of the nearest at any distance; seed facilities in the pilot region. |
| **R10. Pharmacy assigned without stock** — found in the end-to-end test | No pharmacy stocks Atorvastatin, yet the prescription was assigned to Circle Pharmacy and the patient is told "Collect from Circle Pharmacy". | Match and assign per item, and return which items a pharmacy can't fill. |
| **R11. Auto-generated summary** — found in the end-to-end test | Completing a consultation generates and *delivers* the summary straight away, copying the note's Plan as the patient's Advice; its `prescriptions` field was empty although two drugs were prescribed. | Fill `prescriptions` from the consultation's prescriptions, and let the clinician review before it's delivered. |
| **R12. Test data visible to real users** — found in the end-to-end test | "Dr. Fixed Clinician" is listed to patients; "Live Test 1792…" and three "Esi Owusu / Pre-call/call live check" appointments fill Dr. Adjei's queue; stale IN_PROGRESS appointments from yesterday never close. | Clean the demo seed; close or flag appointments left IN_PROGRESS past their slot. |
| **R7. Seeded notifications lack ids** — new | `seed_demo` creates `RESULT_READY` with only `investigation_id`, while real uploads now also send `consultation_id` and `appointment_id`. Demo users can't see the "open the exact result" behaviour. | Seed the same payload the real endpoint sends. |

## P2 — later

PT-N7 rate a clinician · PT-N8 profile photo · PT-N9 NHIS card ·
reschedule (PT-C7) · N6 clinician self sign-up · P4 featured listings ·
PT-S1 WebSocket token in the query string · PT-N6 "everything of mine"
lists · PT-C2 emergency contact on `PatientProfile`.

---

## Open product decisions that block backend work

These need the product owner, not the backend developer, but the backend
can't finish payments or v2 without them:

1. Payment provider (Hubtel, Paystack, MTN MoMo direct).
2. When a consultation is charged, and the refund rules (proposal in
   `carelite_app/docs/PRODUCT_PATHWAY.md`).
3. Commission rates per payee type.
4. Refund when a patient pays for a test and never visits.
5. The v2 timeouts: order expiry 7 days, lab confirmation 2 opening hours,
   result auto-release 48 h.
6. Clinician location precision for in-person visits: region tag,
   coordinates, or both.

---

## Already delivered and in use (verified)

Patient side: PT-B1 unread count, PT-C1 names, PT-C3 appointment filters,
PT-C4 appointment fields, PT-C9 one-step replacement, PT-N2 change
password, PT-N3 logout, PT-N10 messaging, PT-N11 vitals history, PT-N12
record access.
CareLite Pro: B1–B4, C1–C5, N1–N3, N7, realtime, drug suggestions,
pregnancy checks, prescription withdrawal, email login.

## What the apps are fixing themselves (no backend change needed)

So you know what to expect from the apps' side:

**Patient app — done on 16 Oct**
- **Sends the patient's location.** Bookings now carry
  `capture_lat/lng`, and Home saves `last_known_lat/lng` (skipped unless
  the patient has moved about 500 m). Before this, `consultation_origin()`
  had nothing to work with for any new booking.
- `NEW_MESSAGE` opens the conversation; `APPOINTMENT_CANCELLED` opens
  Appointments.
- `RESULT_READY` opens the exact record via `consultation_id`.

- Lists read every page (appointments, notifications, records,
  conversations, access requests, clinician search) by following `next`.
- Booking asks "What do you need help with?" and sends it as `reason`.
- The pre-call banner no longer says "waiting" next to an enabled button.

**Patient app — still to do**
- Release build: signing key, unused packages removed.

**CareLite Pro — done on 16 Oct**
- `NEW_MESSAGE` opens the conversation; `APPOINTMENT_CANCELLED` has its own
  type.
- **Lab section redesigned:** a Home tab (facility header with the
  notification bell, New / In progress / Results due, an urgent-order
  banner, "At the counter" shortcuts for check-in by visit code and result
  entry, up next). Still on sample data until v2 stage 1.
- **Pharmacy section built:** Home, Prescriptions (New / Preparing / Ready /
  Done), a step-by-step order screen (accept with out-of-stock lines
  flagged, pack each line, mark ready, hand over by collection code,
  allergy and pregnancy warnings), Stock (low/out, adjust quantities),
  Wallet. On sample data until the pharmacy contract below exists.
- Reads `facility: {name, type}` from `/api/accounts/me/` the moment L1
  ships and picks the lab or pharmacy screens from it. Until then the
  operator chooses on Account.

Everything else in both apps is waiting on the items above.

---

## Lab and pharmacy contract (what the new screens are built against)

Both facility apps run on an in-memory repository behind the same
interface they'll use for real. Matching these shapes means swapping one
class, with no screen changes.

### Shared

- `facility: {id, name, type, address, phone, operating_hours}` on
  `/api/accounts/me/` for `role=FACILITY` (L1).
- Notifications **to the facility**: `FACILITY_NEW_ORDER` (lab and
  pharmacy), `ORDER_CANCELLED`, plus to the patient on every facility step
  (`ORDER_CONFIRMED`, `READY_FOR_COLLECTION`, `OUT_FOR_DELIVERY`,
  `ORDER_COMPLETED`). Payload always `{order_id, kind}`; the facility apps
  show a live unread badge and open the order from it.
- Realtime: emit the same `notification` socket event the apps already
  listen to, so queues refresh without polling.
- A 6-character **visit / collection code** per order, shown in the patient
  app, checked by the server on check-in and handover (not by the app).

### Lab and imaging (v2 stage 1, already specified)

`GET /api/facility/orders/?status=` · `POST …/{id}/confirm/` ·
`…/reject/ {reason}` · `…/check-in/ {visit_code}` · `…/sample-done/` ·
`…/result/` (see *Results, records and patient access* below) · `GET/PATCH
/api/facility/me/services/` (price, `is_available`). Each order row:
`id, type, priority, status, patient{full_name, age, sex, phone, nhis},
ordered_by_name, items[], total, paid_at, visit_code, clinical_reason,
appointment_at`.

### Pharmacy (new — L4 / PT-L2)

| Endpoint | Body | Effect |
|---|---|---|
| `GET /api/facility/prescriptions/?status=` | — | The queue for this pharmacy |
| `POST …/{id}/accept/` | `{unavailable_item_ids: []}` | `RECEIVED → PREPARING`; patient and prescriber are told which lines can't be filled |
| `POST …/{id}/items/{item_id}/packed/` | `{packed: bool}` | Per-line packing (optional server-side; can stay app-only) |
| `POST …/{id}/ready/` | — | `PREPARING → READY`; patient notified |
| `POST …/{id}/dispatch/` | — | Delivery only: `READY → OUT_FOR_DELIVERY` |
| `POST …/{id}/complete/` | `{collection_code}` | `→ COMPLETED`; releases escrow |
| `POST …/{id}/cancel/` | `{reason}` | Before `READY` only; patient offered another pharmacy |
| `GET /api/facility/me/stock/` | — | `[{id, drug_name, quantity, reorder_level, unit_price}]` |
| `PATCH /api/facility/me/stock/{id}/` | `{quantity, unit_price}` | The shelf matching uses |

Each prescription row: `id, status, patient{full_name, age, sex, phone,
allergies, is_pregnant}, prescriber_name, prescriber_license, items[{id,
drug_name, dosage, frequency, duration, quantity, unit_price, in_stock}],
fulfilment (PICKUP | DELIVERY), delivery_address, received_at,
collection_code, cancel_reason`.

Statuses: `RECEIVED → PREPARING → READY → (OUT_FOR_DELIVERY) → COMPLETED`,
or `CANCELLED`. Forward-only, server-enforced.

Patient side of the same flow (PT-L2): choose pickup or delivery and an
address when the prescription is written, see the status and collection
code, and be told which items weren't supplied.

## Results, records and patient access (R13–R18)

Agreed with product on 17 Oct 2026. CareLite Pro's lab screen now captures
results this way (on sample data). The patient app already reads the new
fields and behaves as before when they're absent, so each item can ship on
its own.

**How results are captured.** The lab attaches the original for every
test: a scan (multi-page PDF), a photo (film, slide, strip) or a file from
the analyser. The original is the source of truth. Values are typed as
well: required for tests with up to 3 parameters, optional for panels such
as FBC, LFT, kidney function, lipids or urinalysis. The clinician compares
the typed values against the original.

### R13. Result upload: values, attachments, flags

`POST /api/facility/orders/{id}/result/`, multipart:

```
note, is_sensitive (bool)
items[i].item_id
items[i].is_critical (bool)
items[i].values[] = {name, value, unit, reference_range, flag}   # flag: N | L | H (LL | HH if the server computes critical)
items[i].attachments[] = file + {sha256, source: SCAN|PHOTO|FILE, captured_at}
```

- **Reject** an item without at least one attachment (400). For a lab item
  with up to 3 parameters, also reject it if its values are missing.
  Imaging needs only the attachment. The app already enforces this rule;
  the server must too.
- **Recompute SHA-256** on receipt. If it doesn't match the app's value,
  reject with 400. Store it, together with uploader user, facility and a
  server timestamp. Attachments are **immutable**: a correction is a new
  version of the result (`AMENDED`, with `amends_id` and a reason), never
  an overwrite.
- Read shape, used by both apps:
  `result: {values[], attachments[{url, name, content_type, sha256,
  uploaded_by, uploaded_at}], note, version, amended_from}`.

### R14. Release to the patient: `release_status`

Add `release_status` and `is_sensitive` to each investigation on every
patient-facing endpoint.

| `release_status` | When | Patient sees |
|---|---|---|
| `PENDING_REVIEW` | result uploaded, not sensitive | "With Dr X… within 48 hours". No values or files. |
| `HELD` | `is_sensitive` | "Your clinician will go through it with you". No values or files. |
| `RELEASED` | clinician marks reviewed, **or** 48 h after upload (non-sensitive only), **or** clinician releases a held one | Everything |

- Auto-release is a scheduled job (same cron as reroute). Sensitive
  results **never** auto-release.
- Don't send `RESULT_READY` to the patient until `RELEASED`.
- The server suggests `is_sensitive` from the test catalogue (HIV, other
  STIs, hCG/pregnancy, mental-health and cancer findings). The lab or the
  clinician can change it, and every change is audited.
- The clinician needs `POST /api/investigations/{id}/release/` (for HELD)
  and the existing review action.

### R15. Critical values

When `is_critical` is set, notify the ordering clinician immediately (push
and socket, `CRITICAL_RESULT` with payload `{investigation_id, consultation_id}`; CareLite Pro opens the result straight from it, as it now does for `RESULT_READY`) and require
`POST /api/investigations/{id}/acknowledge-critical/`. If it isn't
acknowledged within 30 minutes, escalate: notify again, and alert the
facility to phone the clinician. Record the acknowledgement time.

### R16. The care episode ("folder") and its audit trail

Everything from booking to the clinician's report belongs to one
consultation. `GET /api/consultations/{id}/timeline/` returns the ordered
events (booked, call, note versions, orders, sample taken, result
uploaded, amended, reviewed, released, prescription signed, dispensed,
summary), each with `{at, actor_name, actor_role, kind, ref_id}`. It is
built from an **append-only** audit table that every status change writes
to (see recommendation 2 below). The patient app builds this view itself
today; it will switch to the endpoint once it exists.

### R17. Patient access log

`GET /api/patients/me/access-log/` returns who opened my record:
`{at, viewer_name, viewer_role, facility_name, what}`. This means **views**
must be audited, not just writes: opening a consultation, a result or an
attachment. Ghana's Data Protection Act 2012 gives the patient a right of
access, and health data is a special category. Today the audit log is
admin-only, so the patient app's "Shared with" list is derived from record
data.

### R18. Serving result files

Serve result files through short-lived **signed URLs** (5–15 min). Check
the permission on every request: patient (once `RELEASED`), the ordering
clinician, the facility that uploaded it, and anyone the patient has
granted access. No public `/media/` paths (relates to R3). Push payloads
carry **no clinical content**: "You have a new update in CareLite", never
the test name or value.

**Done in the apps, nothing to build server-side.** The patient app has an
optional fingerprint/face lock for Records, off by default. It also asks
for a fingerprint every time a sensitive result is opened. CareLite Pro
computes each file's fingerprint on the device.

## Recommendations from the end-to-end run

1. **One "order" model for labs and pharmacies.** Same lifecycle shape
   (assigned → accepted → in progress → ready/result → completed), same
   facility queue endpoint with a `kind`, same code check, same escrow
   release. Two copies of this logic will drift.
2. **Make status changes events.** Every transition writes an audit row and
   fans out notifications from one place, instead of `notify()` calls
   scattered across views (today there are seven, and most transitions have
   none).
3. **Server-enforced, forward-only transitions** with clear 409s (e.g.
   "already ready"), so two staff at one counter can't double-advance an
   order.
4. **Matching returns "none nearby"** within a radius or region, and only
   facilities that have every item in stock (R9, R10). Never the nearest at
   any distance.
5. **Facility staff accounts belong to a facility** (FK on the user, many
   staff per facility), not one `operator` per facility.
6. **Seed data that tells the pilot's story**: Tamale/Northern Region labs
   and pharmacies with phone numbers, stock and prices, and no test
   accounts.

---

## Appendix — where each "today" was verified (`58ad5f9`)

| Claim | Location |
|---|---|
| Investigation statuses, no patient step | `investigations/models.py` (`InvestigationRequest.Status`) |
| No facility order list; detail/status/result by id only | `investigations/urls.py` |
| Facility acts once assigned | `investigations/views.py` `_can_fulfil` |
| Result notifies patient at upload | `investigations/views.py:231` |
| Lab matching origin = booking capture, then last known | `consultations/services.py:25` |
| Cancel ignores reason, sends nothing | `appointments/views.py:210` |
| All `notify()` call sites (7) | `calls/views.py:85`, `investigations/views.py:231,240`, `access/views.py:59`, `appointments/views.py:42,145`, `messaging/views.py:88` |
| `INCOMING_CALL` payload | `calls/views.py:85` |
| Push only logs | `notifications/channels.py:31` |
| `/media/` not routed | `config/settings.py:167`, `config/urls.py` |
| Reset link | `config/settings.py:220` |
| No clinician `user_id` exposed | `accounts/serializers.py` `PublicClinicianSerializer`, `appointments/serializers.py` `ClinicianBriefSerializer` |
| No facility on `/me`; no `operator` on facility | `accounts/serializers.py`, `facilities/serializers.py` |
| No clinician location | `accounts/models.py` `ClinicianProfile` |
| No payment/escrow model | no match for `escrow`, `payment` models in any app |
| `last_known_lat/lng` writable | `accounts/serializers.py` `PatientProfileSerializer` |
