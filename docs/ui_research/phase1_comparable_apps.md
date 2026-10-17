# Phase 1 — Comparable App Research (Appllama)

Research for the carelite_app UI/UX overhaul. True dedicated telemedicine
video-consult apps (Teladoc, MyChart, Doctolib, Amwell) aren't in Appllama's
top-grossing-apps library — they're distributed via health systems, not
organic App Store charts. Closest available comps are top-grossing
medication/health-tracking apps with overlapping feature sets (appointments,
vitals tracking, care circle, dashboards). Studied in depth:

- **Medisafe Medication Management** (573916946) — $40K/mo, 4.71★, closest
  feature match: Home Dashboard, Appointments, Care Circle, Health Trackers
- **Heartify: Heart Health Monitor** (1546156891) — dark-mode vitals dashboard
- **Wellbeing: Mental&Heart Health** (6450890954) — light dashboard, quick-add tiles
- **Ovia Cycle & Pregnancy Tracker** (570244389) — timeline/feed card pattern

## Cross-app patterns

**1. Card elevation = background-color contrast, not borders or shadows.**
Every app studied (Medisafe, Wellbeing, Ovia) puts pure-white cards
(`#FFFFFF`) on a tinted page background (`#F1F1F3` / `#F2F2F7` / light
grey-blue) with **no visible border and no drop shadow**. The card "pops"
because its background differs from the page, not because of a stroke. This
directly answers the Phase 2 audit finding of 46 card surfaces relying on
`Border.all` — the fix most comp apps converge on isn't adding `BoxShadow`,
it's a two-tier background (tinted scaffold + white card), optionally with a
*very* subtle shadow only on "hero" cards that float over imagery (Medisafe's
Appointments Hub illustration card, Heartify's dark gradient vitals card).

**2. One hero metric card, not a wall of equal-weight tiles.**
Heartify and Wellbeing both lead the vitals dashboard with a single large
"last measurement" card (big number, inline sparkline, secondary stats below)
above a grid of smaller quick-add tiles. Wellbeing's quick-add grid uses soft
pastel-tinted rounded tiles (2-column), color-coded per metric type (green =
heart rate, orange = blood sugar, red = blood pressure, blue = oxygen) —
useful pattern for carelite's vitals trend screen: color becomes a wayfinding
signal, not decoration.

**3. Deep, saturated primary CTA color distinct from the lighter brand/header blue.**
Medisafe uses a lighter blue (#1486C4/#1686C4) for headers/nav and a
noticeably darker navy (#124974–#15476C) for primary buttons — the CTA reads
as "heavier"/more actionable than chrome. Buttons are full-width pill shapes
(fully rounded, ~56-64px tall), which also resolves the audit's 40px
touch-target outliers — every primary action across these apps is well above
48px.

**4. Trend charts: minimal axis, color-coded legend dots, dashed reference line.**
Wellbeing's trends chart uses colored dot legends (Bpm / HRV / Energy) above
a line chart with a dashed horizontal reference line and light vertical
gridlines only — no heavy borders or boxed chart container. Directly
applicable to carelite's existing vitals-trend feature.

**5. Dark mode exists as a first-class alternate, not an inversion.**
Heartify ships a near-black dashboard (not just inverted light colors) for
the vitals/measurement surfaces specifically — high-stakes numeric health
data reads well on dark because the accent line chart (red) pops more than
on white. Confirms the Phase 2 audit gap (zero `ThemeMode`/`Brightness`
handling in carelite_app) is worth closing, at least for data-dense screens.

**6. Consent/legal copy sits inline under the form, small and grey, never a
modal interrupt** (Medisafe's Add Dependent screen) — relevant to carelite's
existing record-access consent flow.

## Direct recommendations feeding Phase 3 (design system)

- Replace `Border.all` card styling with scaffold/card background-color
  contrast; reserve shadow/elevation for cards that float over imagery or
  need to signal "primary/hero" status.
- Standardize primary CTA as a full-width rounded pill in a darker/more
  saturated tone than header chrome; audit confirmed button label font
  weight is already broken (synthetic bold) — fix that in the same pass.
- Raise the three 40px touch targets in `record_access_page.dart` to the
  48px standard already used elsewhere.
- Vitals trend screen: adopt color-coded metric legend + dashed reference
  line + minimal gridlines, matching the existing feature's intent but
  tightening the visual language.
- Scope dark mode to data-dense/clinical screens first (vitals, dashboard)
  rather than a full-app inversion, if phasing is needed.
