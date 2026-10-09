# Product pathway — what CareLite is meant to do for a patient

The product owner's requirements (Sep 2026), with what the patient app does
today and what is waiting on the backend. Backend asks are not repeated
here: each one is in [BACKEND_REQUESTS_PATIENT.md](BACKEND_REQUESTS_PATIENT.md)
under the `PT-` ID shown.

## The intended flow, end to end

1. The patient finds a clinician (virtual first), pays, and consults.
2. The clinician orders tests. The patient is **asked to accept** them.
3. On acceptance a lab **close to the patient** is chosen, the patient
   **pays**, and the money goes to the **lab's wallet**.
4. The patient travels to the lab, with **live directions** and the lab's
   **phone number**.
5. The lab can see the patient's **name, age and phone** so it can reach
   them.
6. Results go to the clinician, who prescribes.
7. The prescription is filled at a pharmacy **close to the patient**. The
   patient chooses **walk-in** (directions and phone) or **delivery**.
8. **Both** patient and clinician get notifications from the lab and
   pharmacy.

Tests and prescriptions are always clinician-initiated. Home never offers a
route straight to a lab or pharmacy, and a test in the app enforces that.

## Where each requirement stands

| Requirement | Patient app today | Waiting on |
|---|---|---|
| Find a Clinician shows no specialty filters | Done: only "Available now", highest rated first | — |
| Find Specialists is specialists only | Done, with hard-coded chips; lists nobody until a specialty is picked | PT-C5, PT-C6 |
| No favorites; ratings stay | Done (favorites never existed) | PT-N7 for patients to rate |
| Patient's location under their name on Home | Done (reverse-geocoded on the phone) | — |
| Paid clinicians listed first | Not built | PT-P2 |
| Patient accepts and pays for tests | Not built | PT-L1, PT-P1 |
| Walk-in or delivery for prescriptions | Not built | PT-L2 |
| Directions and tap-to-call for the lab or pharmacy | Done, on Records. A button shows only when the facility has coordinates or a phone number saved | — |
| Lab and pharmacy see patient name, age, phone | Not the patient app's work | clinician L2 |
| Lab analyst and pharmacist logins | Not the patient app's work | clinician L1 |
| Notifications from labs and pharmacies | App handles unknown types generically | Part 6 |
| Notifications when the app is closed | Not built | PT-N4, a Firebase project |
| Sign up and log in with a phone number | Screen exists, says "coming soon" | PT-N1 |
| Insurance (NHIS or private) | Not built | PT-N9 |
| Cancel with a reason, then offer another clinician | Cancel works and offers another clinician; no reason yet | PT-C7 |
| Clinician unavailable or network error: say so, suggest others | Done for calls, bookings and cancels (see below) | PT-C8 for a clean error code |
| In-person visits, "close to me" | Not built | PT-V1 to V3 |
| Paying for a consultation | Not built | PT-P1, product decision below |

## How "clinician unavailable" works

One sheet is used everywhere a clinician can't be reached. It says what
happened, lists up to three other clinicians, and can be dismissed.

- **Call declined or missed:** "Dr. X can't take the call right now", with
  other clinicians.
- **Call unanswered for 45 seconds:** "Dr. X hasn't answered yet", with
  "Keep waiting" and other clinicians. The server never times a ringing
  call out, so the app does.
- **Booking refused:** the server's reason, with other clinicians.
- **Connection lost** (call or booking): "Your connection dropped" and "Try
  again" only. No other doctor is suggested, because the problem is not the
  doctor.
- **Appointment cancelled:** "Would you like to see another clinician
  instead?"

Who is suggested, in order: online with the same specialty; anyone online;
anyone with that specialty to book a time with. The clinician who was
unavailable is never suggested back.

## In-person visits

Two visit modes exist in the product. **Virtual** is everything built
today. **In-person** is for when the patient has to be physically seen. For
that mode a clinician who is too far away must not be offered at all — a
hard exclusion, not a lower ranking. This is the same pattern the backend
already has for labs and pharmacies (`facilities/matching.py`).

Product owner's rollout plan:

- Rollout starts in **Northern Ghana**. Clinicians are registered by the
  area they work in, so location may arrive as a named area or region
  rather than GPS coordinates.
- On Find a Clinician, **"Close to me" is a filter toggle**, in the same
  row as "Available now". It is not a virtual/in-person switch before
  searching.
- **Continuity matters:** a patient who started virtually should be able to
  book an in-person follow-up with the same clinician as a continuation,
  not a fresh booking.

Why it can't be built yet: `ClinicianProfile` has no location,
`Appointment.mode` only describes *when* (`SCHEDULED` / `ON_DEMAND`), and
the clinician list has no distance filter. No placeholder toggle has been
built, and no invented distance is shown anywhere.

Once PT-V1 to V3 exist: the toggle on Find a Clinician, a distance or area
on each card, a visit type on the booking screens.

## Open product decisions

1. **When is a consultation paid for?** The product owner's framing: the
   patient pays, the money is held, and the clinician is paid when the
   service is done. Undecided: reversal when the consultation doesn't
   happen, and network failures. A proposal to react to:
   - Charge into escrow when the clinician confirms (instantly for
     on-demand).
   - Release when the clinician marks the consultation complete.
   - Refund automatically if the clinician cancels, never joins, or the
     call is never accepted.
   - If the call drops after it was accepted, hold for a short window so
     either side can reconnect, then refund if it was never completed.
   - Patient cancels: full refund before confirmation; a policy decision
     after.

   Charging early protects clinicians from no-shows but makes refunds
   routine. Charging at call start avoids most refunds but lets a patient
   book and not pay.
2. **Does insurance change what the patient pays**, or is it recorded only?
3. **One facility login or separate lab and pharmacist logins?**
   `Facility.type` already tells them apart.
4. **Sharing patient details with labs and pharmacies** is personal health
   data under Ghana's Data Protection Act, 2012. The consent step when the
   patient accepts a test is the proposed basis. Worth a legal check.
5. **Clinician location precision:** region tag, coordinates, or both.
6. **A "Featured" label on paid clinicians** is recommended so patients can
   tell paid placement from rating.
