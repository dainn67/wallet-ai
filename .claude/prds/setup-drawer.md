---
name: setup-drawer
description: Refactor the app drawer to remove redundant navigation, add versioning visibility with a sync script, and implement a currency toggle.
status: complete
priority: P1
scale: small
created: 2026-03-22T00:00:00Z
updated: 2026-03-22T12:25:00Z
---

# PRD: setup-drawer

## Executive Summary
This feature refactors the `HomeScreen` drawer to transition from a navigation-focused component to a utility-focused one. We will remove the redundant tab navigation links, implement a Python script to synchronize app versioning between `pubspec.yaml` and code, and add a currency selection toggle (VND/USD) persisted via `SharedPreferences`.

## Problem Statement
The current drawer duplicates the functionality of the `TabBarView`, providing no unique value to the user. Additionally, there is no way for users to see the app version or switch between currencies (VND/USD), which are essential for a personal finance app.

## Target Users
- **General Users:** Needing to toggle between local and international currencies.
- **Support/QA:** Needing to identify the specific app version for troubleshooting.

## User Stories
**US-1: Currency Selection**
As a user, I want to toggle between VND and USD in the drawer so that I can track my expenses in my preferred currency.

**US-2: Version Visibility**
As a user or developer, I want to see the app's version and build number at the bottom of the drawer so that I know which release I am using.

## Requirements

### Functional Requirements (MUST)

**FR-1: Drawer Cleanup**
Remove "Chat", "Records", and "Test" `ListTile` items from `_buildAppDrawer` in `home_screen.dart`.

**FR-2: Version Configuration**
- Add `version` and `buildNumber` fields to `AppConfig`.
- Display the version at the bottom of the drawer in the format: `v1.0.0(2)`.

**FR-3: Version Sync Script**
Create a Python script `scripts/update_version.py` that:
- Takes a version string (e.g., `1.1.0+3`) as an argument.
- Updates `pubspec.yaml`.
- Updates the hardcoded version values in `lib/configs/app_config.dart`.

**FR-4: Currency Toggle**
- Add a section in the drawer for "Currency".
- Use `ListTile` or a custom toggle to switch between `VND` and `USD`.
- Persist the selection using `StorageService` (key: `user_currency`).
- (Optional but recommended) Update global app state so other components can react to currency changes.

### Non-Functional Requirements
**NFR-1: UI Consistency**
The version number should be styled subtly (smaller font, lower opacity) at the very bottom of the drawer.

## Success Criteria
- Navigation links are removed from the drawer.
- Version string correctly matches the value in `pubspec.yaml` after running the sync script.
- Currency preference is remembered across app restarts.

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
| --- | --- | --- | --- |
| Sync script errors | Low | Low | Use basic string replacement or YAML parsing in Python to ensure `pubspec.yaml` remains valid. |

## Constraints & Assumptions
- **Constraint:** Use `fvm` for Flutter commands.
- **Assumption:** The `StorageService` is already initialized in `main.dart`.

## Out of Scope
- Support for more than two currencies (VND/USD) in this iteration.
- Automatic version incrementing (manual trigger only).

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4]
  nice_to_have: []
  nfr: [NFR-1]
scale: small
discovery_mode: express
validation_status: pending
last_validated: null
