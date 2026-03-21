---
name: setup-font
description: Completely replace google_fonts with local Poppins font assets for offline support and faster loading.
status: backlog
priority: P1
scale: small
created: 2026-03-21T09:55:00Z
updated: null
---

# PRD: setup-font

## Executive Summary
This PRD outlines the removal of the `google_fonts` package and the configuration of local Poppins font assets within the Flutter project. This change ensures better performance, offline support, and a single point of control for future typography changes.

## Problem Statement
The app currently depends on `google_fonts`, which fetches font files from the internet at runtime. This causes a delay in rendering the correct typography (especially on first load or slow connections) and requires an internet connection. Additionally, changing the font family currently involves widespread code changes across the UI.

## Target Users
*Note: Scale is SMALL; Target Users section skipped per rules/prd-quality.md.*

## User Stories
*Note: Scale is SMALL; User Stories section skipped per rules/prd-quality.md (Acceptance Criteria included in Requirements).*

## Requirements

### Functional Requirements (MUST)

**FR-1: Register Local Font Assets**
All Poppins font weights and styles from `assets/fonts/` must be registered in `pubspec.yaml`.

Scenario: Correct Configuration
- GIVEN the font files are present in `assets/fonts/`
- WHEN `pubspec.yaml` is configured with the `Poppins` family
- THEN all font weights (100-900) and styles (normal/italic) are correctly mapped to their respective files.

**FR-2: Set Global Default Font**
The app must use the local `Poppins` font family as the default for the entire application via `ThemeData`.

Scenario: Universal Font Application
- GIVEN `google_fonts` has been removed
- WHEN the app's `ThemeData` is configured with `fontFamily: 'Poppins'`
- THEN all `Text` widgets across the app render using the local Poppins font without any runtime fetching.

**FR-3: Remove `google_fonts` Dependency**
The `google_fonts` package must be completely removed from `pubspec.yaml` and all Dart files.

Scenario: Clean Dependency List
- GIVEN the local font is configured
- WHEN `google_fonts` is removed from `pubspec.yaml` and `fvm flutter pub get` is run
- THEN the app compiles successfully without the library.

### Functional Requirements (NICE-TO-HAVE)
None.

### Non-Functional Requirements

**NFR-1: Fast Load Time**
Fonts must be available immediately on app launch, eliminating any "flash of default font" (FOUT) caused by network fetching.

## Success Criteria
- [ ] No `google_fonts` import remains in any Dart file.
- [ ] All UI elements render with the Poppins font, even in airplane mode.
- [ ] Font weights (Bold, Medium, Light, etc.) are correctly reflected in the UI as per the original design.

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
| :--- | :--- | :--- | :--- |
| Font-specific method breakage | Low | Medium | Perform a global search for `GoogleFonts` and manually update any specific weight/style configurations to standard `TextStyle`. |

## Constraints & Assumptions
- **Assumption:** All required Poppins weights (Thin to Black) are present in the `assets/fonts/` folder.
- **Constraint:** Maintain the `Poppins` look and feel to avoid visual regressions.

## Out of Scope
- Changing the typography design system or font sizes.
- Adding multiple font families.

## Dependencies
- None (removing one).

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3]
  nice_to_have: []
  nfr: [NFR-1]
scale: small
discovery_mode: full
validation_status: pending
last_validated: null
