---
name: update-language-and-currency
description: Implement multi-language support (EN/VI) and update currency management with destructive change protection.
status: complete
priority: P1
scale: medium
created: 2026-03-25T11:00:00Z
updated: 2026-03-26T00:52:00Z
---

# PRD: update-language-and-currency

## Executive Summary
Wally AI needs to support users in different regions by providing localized UI and correct currency tracking. This feature introduces multi-language support (English and Vietnamese) and updates the currency management system (supporting USD and VND). Key aspects include localizing the UI, updating the Chat API to reflect the user's language preference, and implementing a safe "wipe-on-change" mechanism for currency switching to maintain data integrity.

## Problem Statement
Currently, Wally AI is hardcoded to English and VND. 
1. **Language:** Non-English speakers (specifically Vietnamese users) cannot use the app in their native tongue. Additionally, the Chat API always assumes English, leading to potential parsing inaccuracies for Vietnamese input.
2. **Currency:** Users needing to track expenses in USD cannot do so. Changing currency currently doesn't handle existing data correctly, which can lead to mixed-currency history that is mathematically incorrect without complex exchange rate tracking.

## Target Users
- **Vietnamese Users:** Who prefer interacting with the app and AI assistant in Vietnamese.
- **International Users:** Who prefer English or need to track finances in USD.
- **Switchers:** Users who move regions and need to reset their tracking to a new currency.

## User Stories
**US-1: Change Language**
As a **Vietnamese User**, I want to change the app language to Vietnamese so that I can understand the UI better and have the AI respond in my native language.
- [ ] Language toggle (EN/VI) is available in the drawer.
- [ ] UI strings (labels, buttons, hints) update immediately upon change.
- [ ] The language preference is persisted across app restarts.

**US-2: AI Language Awareness**
As an **International User**, I want the AI assistant to know which language I am using so that it can parse my messages more accurately.
- [ ] The active language is sent in the `inputs` body of the Chat API request.

**US-3: Change Currency with Protection**
As a **Switcher**, I want to change my primary currency (USD/VND), and I understand that this will wipe my history to prevent data inconsistency.
- [ ] Currency selection (USD/VND) is available in the drawer.
- [ ] Changing currency triggers a destructive `ConfirmationDialog` (AD-1).
- [ ] Confirming the change wipes all records and resets balances to 0 before applying the new currency.

## Requirements

### Functional Requirements (MUST)

**FR-1: Centralized Configuration**
Define supported languages and currencies in a configuration file for easy expansion.
- Options: Language {English, Vietnamese}, Currency {USD, VND}.
- Location: `lib/configs/app_config.dart` or a dedicated `lib/configs/l10n_config.dart`.
- Scenario: Expansion
  - GIVEN a new currency (EUR) needs to be added
  - WHEN I add 'EUR' to the configuration list
  - THEN the UI automatically shows EUR as an option in the settings.

**FR-2: UI Localization System**
Implement a mechanism to switch UI text based on selected language. For simplicity, use a simple `Map`-based localization or `intl` if easily integrated.
- Initial scope: All core screens (Home, Chat, Records, Popups).
- Scenario: Language Switch
  - GIVEN the app is in English
  - WHEN the user selects 'Vietnamese' in the drawer
  - THEN the drawer, tabs, and all popups display Vietnamese text.

**FR-3: API Language Synchronization**
Modify `ChatApiService.streamChat` to dynamically include the active language in the request body.
- Scenario: Active Language in Payload
  - GIVEN the user has selected 'Vietnamese'
  - WHEN a chat message is sent
  - THEN the request payload includes `'language': 'Vietnamese'`.

**FR-4: Destructive Currency Change**
Integrate currency switching with the existing `resetAllData` logic.
- Scenario: Currency Switch with Data Wipe
  - GIVEN the user has existing VND records
  - WHEN they select 'USD' as the currency and confirm the "Wipe All Data" warning
  - THEN all VND records are deleted, source balances are set to 0, and the currency symbol becomes '$'.

**FR-5: Persistence**
Store selected language and currency in `SharedPreferences`.
- Scenario: Persistence Check
  - GIVEN the user has set the language to Vietnamese
  - WHEN the app is closed and reopened
  - THEN the app initializes in Vietnamese.

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Automatic Language Detection**
Default the app language based on the system locale on first run.
- Scenario: First Run
  - GIVEN the user's device is set to Vietnamese
  - WHEN the app is opened for the first time
  - THEN the app defaults to Vietnamese.

### Non-Functional Requirements

**NFR-1: Zero Latency UI Update**
UI text should update within 100ms of selection without requiring a manual app restart.

**NFR-2: Data Integrity**
Ensure currency change and data wipe are atomic. The currency must not change if the database reset fails.

## Success Criteria
- **SC-1: UI Translation Coverage**: 100% of core UI strings (Drawer, Tabs, Popups) translated into English and Vietnamese. Measured by code audit.
- **SC-2: API Synchronization**: 100% of `ChatApiService` requests include the correct `language` metadata. Verified via integration tests.
- **SC-3: Reset Accuracy**: 0 records remaining after a currency change. Verified via unit tests.

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
| :--- | :--- | :--- | :--- |
| Unintended Data Loss | High | Low | Use the red destructive style for the confirmation dialog and explicit warning text mentioning the target currency. |
| Missing Translations | Medium | Medium | Implement a fallback mechanism to English for any missing keys. |
| API Incompatibility | Medium | Low | Verify backend support for language strings ("Vietnamese" vs "English") via manual testing. |

## Constraints & Assumptions
- **Constraint:** Must use the `ConfirmationDialog` created in the `reset-all` epic.
- **Assumption:** No real-time exchange rate conversion is required; data is simply wiped.
- **Assumption:** The app only supports one primary currency at a time.

## Out of Scope
- Support for more than EN/VI and USD/VND in this iteration.
- Multiple wallets with different currencies.
- Custom user-defined currencies.

## Dependencies
- **AppConfig / StorageService** [Owner: Core Service | Status: Ready] — For persisting preferences.
- **ChatApiService** [Owner: Networking | Status: Ready] — For sending language metadata.
- **RecordProvider** [Owner: State Mgmt | Status: Ready] — For triggering the reset flow.

## _Metadata
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2]
scale: medium
discovery_mode: full
validation_status: passed
last_validated: 2026-03-25T11:25:00Z
