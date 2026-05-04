---
name: onboarding
description: First-launch modal dialog with 3 sequential slides introducing AI chat, Records, and drawer settings; dismissed only via final "Got it"; shown once via SharedPreferences flag.
status: backlog
priority: P1
scale: small
created: 2026-04-28T03:12:34Z
updated: 2026-04-28T03:14:14Z
---

# PRD: onboarding

## Executive Summary

On first launch, Wally AI shows a full-screen modal dialog guiding new users through its three core workflows: AI-powered chat entry, the Records dashboard, and Language/Currency settings in the drawer. The dialog is non-dismissible until the user steps through all three slides and taps "Got it"; a SharedPreferences flag ensures it never appears again after completion.

## Problem Statement

New users open the app with no context about how it works. The primary value proposition — type a message and the AI creates a record automatically — is non-obvious. Users who skip past the Chat tab or don't discover the drawer settings never realise the app's full capability. There is currently no introduction of any kind.

## Target Users

First-time installers — any user whose device has no existing SharedPreferences key for onboarding completion.

## Requirements

### Functional Requirements (MUST)

**FR-1: First-launch gate**
Show the onboarding dialog automatically when the app opens and `onboarding_complete` is not set (or `false`) in SharedPreferences. Do not show on any subsequent launch once the flag is set.

Scenario: First launch
- GIVEN the user has installed and opened the app for the first time
- WHEN the home screen initialises
- THEN the onboarding dialog is displayed before any tab content is interactable

Scenario: Returning launch
- GIVEN the user has previously completed onboarding (`onboarding_complete = true`)
- WHEN the app opens
- THEN no dialog is shown and the home screen loads normally

**FR-2: Sequential 3-slide navigation**
The dialog contains exactly 3 slides navigated in order. Slide 1 and 2 show a "Next" button; slide 3 shows a "Got it" button. The user cannot skip forward to a later slide, cannot go back, and cannot dismiss the dialog by tapping outside or pressing the system back button.

Scenario: Advancing slides
- GIVEN the onboarding dialog is open on slide 1 or 2
- WHEN the user taps "Next"
- THEN the dialog advances to the next slide

Scenario: Blocked dismissal
- GIVEN the onboarding dialog is open on any slide
- WHEN the user taps outside the dialog or presses the Android/iOS back button
- THEN the dialog remains visible on its current slide; no navigation, dismissal, or animation occurs

Scenario: Swipe gesture blocked
- GIVEN the onboarding dialog is open on slide 1 or 2
- WHEN the user swipes left or right on the slide content
- THEN no slide transition occurs (PageView uses NeverScrollableScrollPhysics)

**FR-3: Configurable slide content**
Each slide displays a screenshot image and a descriptive text string below it. Slide data is defined as a `const` list of slide objects (image asset path + text string) in a single location within the widget file, so adding or reordering slides requires changing only that list. Placeholder assets must be provided at build time; final images will be supplied by the designer and swapped in without code changes.

Slide definitions (initial):
- Slide 1 — image: `assets/onboarding/slide_1.png` | text: "Just chat and the AI handles your tracking automatically."
- Slide 2 — image: `assets/onboarding/slide_2.png` | text: "View and manage all your income and expense records easily."
- Slide 3 — image: `assets/onboarding/slide_3.png` | text: "Change language and currency anytime from the menu drawer."

Scenario: Slide content displayed
- GIVEN the onboarding dialog is showing slide N (1, 2, or 3)
- WHEN that slide is rendered
- THEN the image asset configured for slide N is shown above the descriptive text configured for slide N

**FR-4: Completion flag**
When the user taps "Got it" on slide 3, set `onboarding_complete = true` in SharedPreferences, then dismiss the dialog.

Scenario: Completing onboarding
- GIVEN the user is on slide 3
- WHEN the user taps "Got it"
- THEN `onboarding_complete` is written to SharedPreferences, the dialog closes, and the app is fully usable

### Non-Functional Requirements

**NFR-1: No external dependencies**
The onboarding widget must not require network access. All images are bundled assets. SharedPreferences is already in the dependency tree.

**NFR-2: Back-button lock**
Back button or back gesture press while the onboarding dialog is visible produces no dismissal or navigation on any slide, on both Android and iOS.

## Success Criteria

| Criterion | Target | How to Measure |
|-----------|--------|----------------|
| Dialog shown on first launch | 100% of fresh installs | Manual QA on clean install |
| Dialog not shown on second launch | 100% | Manual QA after completing onboarding |
| User must reach slide 3 to dismiss | 100% (no early exit path) | Code review + QA |
| Image swap requires no code change | Asset path only | PR review checklist |

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Placeholder images not ready at build time — causes blank slides | Med | Med | Ship solid-colour placeholder PNGs in repo; designer swaps assets before release |
| SharedPreferences write fails (rare device edge case) | Low | Low | Dialog dismisses regardless; worst case user sees it once more on next launch |
| Dialog feels intrusive / blocks returning users after reinstall | Med | Low | Accepted — onboarding shows once per install, standard mobile pattern |

## Constraints & Assumptions

**Constraints:**
- `shared_preferences` package is already a project dependency.
- Image assets must be declared in `pubspec.yaml` under `flutter.assets`.
- No new third-party packages.
- Use `PopScope` / `WillPopScope` (Flutter version appropriate) to intercept system back gesture on Android; use `Navigator`-level route settings to block iOS swipe-back if dialog is pushed as a route.

**Assumptions:**
- Three slides cover the core value proposition adequately. If wrong, an additional slide can be added by extending the slide config list.
- The designer will supply final PNGs before the release build. If wrong, placeholder images ship and a follow-up asset-swap PR is made.
- The SharedPreferences key `onboarding_complete` is not already used elsewhere in the codebase.

## Out of Scope

- Skip button or early-exit path — users must reach "Got it"
- Re-openable onboarding from settings/drawer
- Animated transitions between slides (plain `PageView` is sufficient)
- Interactive tutorial (tap targets, overlays, tooltips)
- Server-side tracking of onboarding completion

## Dependencies

- `assets/onboarding/slide_1.png`, `slide_2.png`, `slide_3.png` — Designer — pending (placeholders to be committed by developer)

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4]
  nice_to_have: []
  nfr: [NFR-1, NFR-2]
scale: small
discovery_mode: express
validation_status: warning
last_validated: 2026-04-28T03:49:19Z
