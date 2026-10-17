# Phase 3 — Design System

Builds directly on [Phase 1 research](phase1_comparable_apps.md) and the
Phase 2 code audit. Every rule below exists to fix a specific, named problem
in the current app, not as a stylistic preference. Token values marked
**NEW** don't exist in `app_colors.dart` yet — see "Figma sync" at the end
before anyone treats them as final.

## Problems this resolves

| # | Audit finding | Root cause found in code | Fix |
|---|---|---|---|
| 1 | 46 cards use `Border.all`, zero `BoxShadow` | Every card (`FormCard`, `NotificationCard`, `_VitalsCard`, etc.) is a white box with a 1px `AppColors.border` stroke on a *white* scaffold | §1 Surfaces — tint the scaffold, drop the border |
| 2 | `buttonLabel` requests Inter 700, only 400/500/600 bundled | `pubspec.yaml` fonts block is missing `Inter-Bold.ttf` | §3 Typography |
| 3 | No dark mode | Single `ThemeData` in `app.dart`, no `darkTheme`/`themeMode` | §5 — scoped, not deferred to "someday" |
| 4 | 3 touch targets at 40px in `record_access_page.dart` | `minimumSize: const Size(0, 40)` — no shared constant for the 48px floor, so it drifted | §4 — `AppSpacing.touchTarget` |
| 5 | (new, found during this pass) `teal` is both the primary CTA color (`PrimaryButton`) and a general accent/icon color (nav selection, links, section headers) — no visual distinction between "do this" and "this is clickable/informational" | No role separation in `app_colors.dart` | §2 Color roles |
| 6 | (new) Screens set scaffold background ad hoc — `vitals_trend_page.dart` hardcodes `AppColors.lightGrayBg`, everything else inherits the global theme's plain white | No scaffold background in `ThemeData` | §1 Surfaces |

## 1. Surfaces — tinted scaffold, borderless card

Every comp app studied in Phase 1 (Medisafe, Wellbeing, Ovia) gets card
"pop" from background-color contrast, not a stroke:

- **Scaffold background**: `AppColors.lightGrayBg` (#F1F5FA) — set once in
  `ThemeData.scaffoldBackgroundColor`, not per-screen. Removes the
  inconsistency where some screens opt into a tint and most don't.
- **Card background**: `AppColors.white`, **no border**. Delete
  `border: Border.all(color: AppColors.border)` from `FormCard`,
  `NotificationCard`, `_VitalsCard`, `appointment_card.dart`,
  `provider_card.dart`, and the other 20 call sites.
- **`AppColors.border` is not deleted** — keep it for actual dividers
  (hairlines between list rows) and for interactive outlines (an unselected
  filter chip, a text field's resting state) where a stroke communicates
  "boundary of an input," not "boundary of a content block." Those are a
  different job than card elevation and comp apps draw that line the same
  way (Medisafe's form-sheet text fields keep hairline dividers; its content
  cards don't).
- **Hero/floating cards** (the one card per screen carrying the primary
  metric or illustration — Appointments Hub style, or a future vitals
  "latest reading" hero) may use a soft shadow: `BoxShadow(color:
  AppColors.ink.withValues(alpha: 0.06), blurRadius: 16, offset:
  Offset(0, 4))`. Reserve this for the one or two cards per screen that are
  genuinely primary — if every card gets a shadow it's a border with extra
  steps.

## 2. Color roles

Current problem: `teal` fires for the primary CTA *and* for nav-selected
state, icons, and accents — a patient can't learn "teal = do this" because
teal is everywhere. `navy` already exists as a token and is used nowhere
except the splash screen icon.

Reassign roles using **existing tokens only** — no new colors needed:

| Role | Token | Was | Now |
|---|---|---|---|
| Primary action (buttons, FAB) | `AppColors.navy` | splash icon only | `PrimaryButton` background |
| Accent / selected / informational | `AppColors.teal` | primary button + accent | nav selection, links, icons, section headers (unchanged — just no longer also the button color) |
| Secondary/chrome accent | `AppColors.blue` | mixed with teal inconsistently | unchanged — already used for secondary color scheme slot |

This mirrors the Phase 1 finding directly: comp apps keep the button color
*darker and more saturated* than header/chrome accents so the CTA reads as
more "committed." Navy (#1B3B8C) against teal (#1A9EB0) gives exactly that
relationship, and it's a one-line change in `PrimaryButton` — no new token,
no Figma drift.

Secondary buttons (e.g. `NotificationCard`'s outlined action, "More info" /
"View notes" style from Medisafe): outlined, `AppColors.navy` text/border on
transparent — never teal, so the hierarchy (primary=solid navy,
secondary=outlined navy) stays legible without adding a third button color.

## 3. Typography — fix the synthetic bold, don't redesign the ramp

`buttonLabel` (Inter, weight 700) has been synthetic-bolded on every button
in the app since `Inter-Bold.ttf` was never added to `pubspec.yaml`. Two
ways to fix it; take the first:

- **Preferred**: add `assets/fonts/Inter-Bold.ttf` and register it at
  weight 700 in `pubspec.yaml`. Zero code changes, matches the original
  design intent (buttons were meant to read heavier than body text), and
  Poppins already does this correctly (700 is bundled) so it's just
  catching Inter up to the same standard.
  Only fall back to weight 600 in `buttonLabel` if there's a reason the Inter
  Bold file can't be sourced.

No other change to the type ramp — h1/h2/body/bodyMuted/caption all read
correctly against Phase 1 comps (Medisafe and Wellbeing both use a similarly
restrained 2-weight headline/body split).

## 4. Touch targets — make the 48px floor a token, not a convention

`PrimaryButton` already comments "48dp floor... regardless of label length"
but encodes it as a literal `48`. `record_access_page.dart` independently
wrote `Size(0, 40)` three times with nothing to contradict. Add:

```dart
// app_spacing.dart
static const double touchTarget = 48;
```

Replace every `minimumSize: const Size(0, 40)` in `record_access_page.dart`
and the literal `48` in `primary_button.dart` with
`AppSpacing.touchTarget`. This is a token-naming fix as much as a sizing
fix — the next person who writes a button has something to reach for
instead of guessing a number.

## 5. Dark mode — scoped, not deferred indefinitely

Full-app dark mode is a large surface to redesign and re-test (per-screen
contrast, image/illustration variants, status bar styling) and the Phase 1
research doesn't support doing it everywhere at once anyway — Heartify's
near-black treatment is deliberately reserved for data-dense vitals/metric
screens, not applied app-wide.

Recommended scope for this round: **vitals trend + home dashboard only**,
driven by `Theme.of(context).brightness` via a real `darkTheme` +
`ThemeMode.system` in `app.dart` (not a manual per-widget `if` chain).
Every other screen keeps its current light treatment until a later pass
earns it with real usage data.

This needs dark-surface color tokens that don't exist yet (`inkSurface` for
the near-black background, a readable variant of `teal`/`navy` against it,
etc. — same category as the existing `white70` token, which was added
ad hoc for the one dark Call screen that already exists). **Do not invent
these in code first** — see Figma sync below.

## 6. Component specs for Phase 4

- **Card** (`FormCard`, `NotificationCard`, `_VitalsCard`, `appointment_card.dart`, `provider_card.dart`): white, `radiusXl` (20, unchanged — already consistent), no border, no shadow unless hero (§1).
- **PrimaryButton**: background `navy` (was `teal`), unchanged shape/sizing (`radiusLg`, `touchTarget` height), `buttonLabel` style unchanged once Inter Bold is bundled.
- **Secondary/outlined button**: new, needed for `NotificationCard`'s "More info"-style actions — outline `navy` at full opacity, text `navy`, transparent fill, same `touchTarget` height.
- **Vitals hero card** (new, for the home dashboard integration implied by Phase 1 finding #2): one large card per screen — latest reading, big number, inline sparkline, 2-3 secondary stats below, optional soft shadow per §1. Below it, a 2-column grid of color-coded quick-add tiles (blood pressure, pulse, SpO2, weight, etc.), each tinted at ~12% of its metric's accent color — same technique `NotificationCard` already uses for its icon badges (`accent.withValues(alpha: 0.12)`), just extended to a bigger surface. This reuses an existing pattern rather than introducing a new one.
- **Trend chart** (`vitals_trend_page.dart`): keep the existing card-per-reading list (it's the right call for a read-only clinician-entered log, unlike a comp app's patient-logged daily trend), but if/when a chart view is added, follow §1's finding: color-coded legend dots, dashed reference line, minimal gridlines, no boxed chart container.

## Figma sync — action needed before Phase 4 touches color tokens

`app_colors.dart`'s own header says "do not invent new colors here without
updating Figma first." Everything in §1–§4 above uses **existing** tokens
(`navy`, `teal`, `blue`, `border`, `lightGrayBg`) reassigned to clearer
roles — no new colors, nothing to sync.

§5 (dark mode) is the exception: it needs new dark-surface tokens that
don't exist in Figma yet. Decision (2026-10-16): Figma is out of scope for
this round — the dark-surface tokens are added in code in Phase 4, treating
`app_colors.dart` as the source of truth for now. Whoever owns the Figma
file should backfill them there when convenient; they're flagged `// NEW —
not yet in Figma` at the token definition so they're easy to find.
