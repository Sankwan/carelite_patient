# CareLite patient app (Flutter)

The patient side of CareLite ("Care Beyond Distance"), a telemedicine
platform for Ghana. Patients find a clinician, book, consult, and see their
records. Clinicians use a separate app (`carelite_clinician`). Both talk to
the team's Django REST API.

## Run

1. Start the backend (see [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md)).
2. Run the app:

   ```bash
   flutter pub get
   flutter run --dart-define=DJANGO_API_BASE_URL=http://10.0.2.2:8000
   ```

   `10.0.2.2` is the Android emulator's address for the host machine. Demo
   login: `kofi` / `carelite123`.

   No emulator? Run it in a browser instead — no flags needed:

   ```bash
   flutter run -d chrome
   ```

3. Validate:

   ```bash
   flutter analyze && flutter test
   ```

## Docs

- [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md) — what is built, how the
  app talks to the backend, known gaps, what to do next.
- [docs/PRODUCT_PATHWAY.md](docs/PRODUCT_PATHWAY.md) — what the product is
  meant to do, and open product decisions.
- [docs/BACKEND_REQUESTS_PATIENT.md](docs/BACKEND_REQUESTS_PATIENT.md) —
  every ask of the backend developer.
