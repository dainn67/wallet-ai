---
name: home-widgets
description: Redesign all Android widget layouts with consistent "Add a record" bar and differentiated write/camera quick-action icons on medium/large breakpoints.
status: complete
priority: P1
scale: medium
created: 2026-06-01T09:32:07Z
updated: 2026-06-02T15:46:34Z
---

# PRD: home-widgets

## Executive Summary

The Wally AI Android home widget currently offers a single undifferentiated tap target across all layout sizes — every interaction opens the app the same way regardless of what the user intended. We are redesigning all five responsive breakpoints to surface a clear "Add a record" entry bar on every size, and adding distinct **write** and **camera** quick-action icons on medium and large layouts that deep-link directly to the focused chat input or the camera picker respectively. The interaction model stays deliberately simple: all widget elements are plain Glance UI (no real in-widget text field), tapping any element opens the app and routes to the appropriate screen. This change reduces the steps to log an expense from the home screen from 3+ taps to 1.

## Problem Statement

Users who want to quickly log an expense from their phone's home screen face a flat, undifferentiated widget experience. The existing `QuickRecordBar` opens the app but always lands on the root screen — there is no shortcut to the camera (for receipt capture) or to a pre-focused text input. On the 1×1 layout, the bar shows only an edit icon with no label, giving new users no affordance to understand what the widget does. On larger layouts the extra space is filled with stats but the action area remains a single generic bar.

The workaround today is to open the app manually and navigate to the ChatTab, then tap the text input or camera button — typically 3–4 interactions. This friction is significant for the app's core habit loop (log every expense immediately) since high-friction logging leads to forgotten or skipped records.

## Target Users

**Habitual Logger — "Daily Dainn"**
- A returning user who opens Wally at least once per day to log transactions as they happen.
- Encounters the widget every time they unlock their phone.
- Primary need: log an expense in one tap, ideally without fully loading the app.
- Pain level: **High** — the current widget doesn't shorten the path vs. just tapping the app icon.

**Receipt Capturer — "Photo-first Phong"**
- A user who prefers snapping a receipt photo and letting the AI parse it rather than typing.
- Reaches for the camera frequently throughout the day.
- Primary need: one-tap access to camera from home screen.
- Pain level: **High** — camera is currently buried two taps deep inside the app.

## User Stories

**US-1: Recognisable entry point on every widget size**
As a Daily Dainn, I want every widget size to clearly show "Add a record" so that I immediately understand the widget's purpose even after a fresh install.

Acceptance Criteria:
- [ ] All five layout breakpoints (1×1, 1×2, 2×1, 2×2, 3×2+) show the "Add a record" label or icon-with-label bar.
- [ ] The 1×1 layout shows at minimum an edit icon; all other layouts show the label text alongside the icon.
- [ ] Tapping the bar on any layout opens the app with the ChatTab active and the text input focused.

**US-2: Camera quick-action on medium and large layouts**
As a Photo-first Phong, I want a camera icon on the widget that opens the camera directly so that I can capture a receipt in one tap.

Acceptance Criteria:
- [ ] Camera icon is visible on 2×2 and 3×2+ layouts.
- [ ] Tapping the camera icon opens the app and immediately triggers the camera picker (same behaviour as tapping the camera button inside the ChatTab).
- [ ] The camera icon is visually distinct from the write icon.

**US-3: Write quick-action on medium and large layouts**
As a Daily Dainn, I want a write/keyboard icon alongside the camera icon so that I can choose typed vs. photo entry directly from the widget.

Acceptance Criteria:
- [ ] Write (keyboard/pencil) icon is visible on 2×2 and 3×2+ layouts, positioned to the left of the camera icon.
- [ ] Tapping the write icon opens the app with the ChatTab active and the text input focused (same as tapping the bar).
- [ ] Tapping anywhere outside the icon row or bar still opens the app root (no crash, no no-op).

**US-4: Consistent fallback — tap anywhere opens app**
As a Daily Dainn, I want tapping any non-interactive area of the widget to open the app so that I am never stranded with a dead tap.

Acceptance Criteria:
- [ ] The widget background/container has a root click action that opens the app.
- [ ] This fallback does not conflict with more specific icon/bar actions.

## Requirements

### Functional Requirements (MUST)

**FR-1: "Add a record" bar on all layouts**
Every layout breakpoint must include a visually prominent entry bar with an edit icon and the label "Add a record". On any breakpoint whose width is ≤ 80 dp (including 1×1 and 1×2 TALL), the label may be omitted — the icon must remain. All breakpoints wider than 80 dp must show the label text alongside the icon. Tapping the bar fires `homeWidget://record`.

Scenario: Standard tap on medium layout bar
- GIVEN the user has the 2×2 widget on their home screen
- WHEN they tap the "Add a record" bar
- THEN the app opens, navigates to ChatTab, and focuses the text input within 800 ms end-to-end from tap

Scenario: 1×1 compact — icon-only bar
- GIVEN the widget is placed at 1×1 (≤ 80 dp wide)
- WHEN the user views the widget
- THEN only the edit icon is shown (no label) and tapping it fires `homeWidget://record`

**FR-2: Write icon quick-action (medium and large)**
On 2×2 and 3×2+ layouts a pencil icon must be rendered as a tappable element paired beside the camera icon, forming a two-icon action row. It fires `homeWidget://record`. Its purpose is visual symmetry with the camera icon — users see "type vs. photo" as a deliberate choice, rather than the bar alone implying only one entry mode. The "Add a record" bar remains the primary tap-anywhere affordance; the write icon is a complementary shortcut.

Scenario: Write icon tap
- GIVEN the user has a 2×2 or larger widget
- WHEN they tap the write icon
- THEN the app opens with ChatTab active and text input focused (same destination as the bar)

**FR-3: Camera icon quick-action (medium and large)**
A camera icon must be rendered as a distinct tappable element on 2×2 and 3×2+ layouts, positioned to the right of the write icon. Tapping fires `homeWidget://camera`.

Scenario: Camera icon tap
- GIVEN the user has a 2×2 or larger widget
- WHEN they tap the camera icon
- THEN the app opens and immediately presents the image picker / camera (same as tapping the camera button in ChatTab)

Scenario: Camera permission not granted
- GIVEN camera permission has not been granted
- WHEN the user taps the camera icon on the widget
- THEN the app opens the ChatTab and surfaces the system camera permission prompt

**FR-4: Deep-link routing in the app**
`HomeScreen` (or `MainActivity`) must handle two widget deep-link URIs:
- `homeWidget://record` → navigate to ChatTab, request focus on the text input
- `homeWidget://camera` → navigate to ChatTab, trigger the camera picker

Scenario: App already running, homeWidget://camera received
- GIVEN the app is in the background
- WHEN `homeWidget://camera` intent arrives
- THEN the app comes to foreground, switches to ChatTab, and opens the camera picker without requiring any additional user tap

**FR-5: Root fallback tap opens app**
The widget's root container must have a default click action (`actionStartActivity`) that opens the app to its default screen (ChatTab or last-visited tab). This fires when the user taps any area not covered by the bar or action icons.

Scenario: Tap on stats area
- GIVEN the user has a 3×2+ widget showing balance and income/spent stats
- WHEN they tap the stats text area
- THEN the app opens (no crash, no no-op)

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Haptic feedback on widget tap**
Trigger a light haptic impulse when any widget tap is registered, before the app opens, to provide immediate tactile confirmation. Deferred because Glance haptics require API 31+ and adds complexity for minor UX gain.

Scenario: Tap with haptic
- GIVEN the device is API 31+ and haptics are enabled
- WHEN the user taps the bar or any icon
- THEN a light haptic pulse fires immediately on tap

**NTH-2: iOS WidgetKit widget**
Cross-reference only — tracked in `home-widget.md` PRD. Not actioned in this epic. Listed here for completeness so the iOS counterpart is discoverable from this document.

Scenario: iOS widget tap opens app to ChatTab
- GIVEN the user has added the Wally widget to their iPhone home screen
- WHEN they tap the "Add a record" bar
- THEN the app opens to ChatTab with the text input focused

### Non-Functional Requirements

**NFR-1: App foreground time**
The app must reach the target screen (ChatTab with input focused or camera open) within 800 ms of the widget tap on a mid-range device (Snapdragon 6xx equivalent). Measured from tap to UI-ready state.

**NFR-2: Widget rendering correctness**
All five layout breakpoints must render without overflow, clipping, or missing elements across Android API 26–34. Verified by manual inspection on emulator at each `DpSize` breakpoint defined in `AppWidget.kt`.

**NFR-3: Glance state freshness**
Widget data (balance, income, spent, month) must reflect the app's current state within 30 seconds of any record being created, updated, or deleted. The existing `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget` call in `RecordProvider` already satisfies this — must not regress.

## Success Criteria

1. **One-tap to log**: A user can go from home screen → ChatTab with text input focused in 1 tap and ≤ 800 ms. Measured manually on a physical device at each layout size.
2. **One-tap to camera**: A user can go from home screen → camera picker in 1 tap and ≤ 800 ms. Measured manually.
3. **Zero dead taps**: Tapping any pixel of the widget produces a visible app response (opens app). Verified by tapping 10 distinct non-icon areas across all 5 layouts — 0 no-ops expected.
4. **Layout completeness**: All 5 breakpoints render the "Add a record" entry affordance with no visual overflow on emulator API 26, 30, 34.

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| `homeWidget://camera` deep-link conflicts with existing `homeWidget://record` routing in `HomeScreen._handleWidgetClick` | High | Medium | Extend the existing `Uri` switch in `_handleWidgetClick` to branch on `homeWidget://camera`; add the camera trigger path before adding the widget URI |
| Glance `clickable` area overlap — root fallback captures icon taps | High | Low | Apply icon `clickable` modifiers before the root container modifier; Glance resolves the innermost clickable first |
| Camera permission not granted at widget tap time | Medium | Medium | Route through the same `_handleCameraPermission` path already used in ChatTab; no new permission logic needed |
| Layout overflow on narrow/tall breakpoints (1×2) with added icon row | Medium | Medium | Icon row only appears on 2×2+; 1×2 `VerticalDashboard` keeps current compact button |

## Constraints & Assumptions

**Constraints:**
- Android Glance does not support real `TextField` — all "input" affordances are visual-only and tap to open app.
- Widget layout is controlled by `SizeMode.Responsive` — layouts map to the 5 existing `DpSize` breakpoints in `AppWidget.kt`.
- Icons must use Android system drawables (`android.R.drawable`) or bundled vector assets — no Flutter asset loading from Glance context.

**Assumptions:**
- The camera deep-link can reuse the existing camera-picker trigger in `ChatTab` via a flag passed through the `Intent` extras or URI. If wrong, a new dedicated entry point in `HomeScreen` will be needed (adds ~1 day of work).
- `homeWidget://record` already focuses the chat text input on arrival — confirmed by existing `_handleWidgetClick` logic. If the focus behaviour has regressed, it must be fixed as part of this feature.
- Icon row (write + camera) fits within 2×2 layout (160×160 dp) without crowding the stats. If wrong, the icon row may need to replace the stats row on 2×2 and stats move to 3×2+ only.

## Out of Scope

- **Real in-widget text input** — Android OS constraint; not buildable without a full overlay Activity (NTH-1 territory for a future sprint).
- **iOS WidgetKit widget** — no Swift file exists; separate platform effort tracked in `home-widget.md` PRD.
- **New data shown on widget** — budget bars, category breakdown, last transaction — not requested; avoids scope creep.
- **Widget configuration screen** — letting users choose what data to show — future iteration.
- **Tablet / large-screen breakpoints** — existing breakpoints cover phone form factors; tablets not in scope.

## Dependencies

- `HomeScreen._handleWidgetClick(Uri?)` — must be extended for `homeWidget://camera` — owner: this epic — status: pending
- Camera picker trigger logic in `ChatTab` — must be callable from `HomeScreen` on deep-link arrival — owner: this epic — status: pending
- `AppWidget.kt` Glance composables — full rewrite of layout composables — owner: this epic — status: pending
- `home_widget` Flutter package (v0.9.x) — already in `pubspec.yaml` — status: resolved
- `androidx.glance:glance-appwidget 1.1.x` — already in `build.gradle.kts` — status: resolved

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5]
  nice_to_have: [NTH-1, NTH-2]
  nfr: [NFR-1, NFR-2, NFR-3]
scale: medium
discovery_mode: full
validation_status: warning
last_validated: 2026-06-01T09:37:42Z
