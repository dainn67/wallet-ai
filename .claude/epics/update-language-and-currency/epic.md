---
name: update-language-and-currency
status: done
created: 2026-03-25T11:30:00Z
progress: 100%
priority: P1
prd: .claude/prds/update-language-and-currency.md
task_count: 7
github: "https://github.com/dainn67/wallet-ai/issues/112"
updated: 2026-03-25T13:10:00Z
---

# Epic: update-language-and-currency

## Overview
This epic implements multi-language support (English and Vietnamese) and updates currency management (USD and VND). It ensures the AI assistant is aware of the user's language preference and protects data integrity by wiping transaction history when switching primary currencies.

## Architecture Decisions

### AD-3: Centralized Localization Configuration
**Context:** Language and currency options are currently hardcoded or missing.
**Decision:** Create `lib/configs/l10n_config.dart` to store supported Locales, Currencies, and their associated UI strings.
**Alternatives rejected:** Hardcoding strings in widgets (hard to maintain) or using full `intl` boilerplate (potential over-engineering for 2 languages).
**Trade-off:** Manual Map-based translations require discipline but keep the codebase extremely simple and offline-first.

### AD-4: LocaleProvider for State Management
**Context:** UI needs to refresh immediately when language/currency changes.
**Decision:** Implement `LocaleProvider` as a `ChangeNotifier` to hold `currentLocale` and `currentCurrency`.
**Trade-off:** Standard Provider pattern ensures reactive updates across the entire app.

### AD-5: Atomic Currency Change with Wipe
**Context:** Mixed currencies in history cause calculation errors.
**Decision:** Changing currency must trigger `RecordProvider.resetAllData()` before updating the stored preference.
**Trade-off:** Users lose data on change, but data integrity is guaranteed.

## Technical Approach

### UI Layer
- **Language/Currency Toggles:** Add dropdowns or toggles in the Navigation Drawer under "Preferences".
- **Dynamic Text:** Replace hardcoded strings with `context.watch<LocaleProvider>().translate('key')`.

### State & Data Layer
- **LocaleProvider**:
    - Manage `Locale` and `Currency` states.
    - Persist to `SharedPreferences` via `StorageService`.
    - Provide `translate(key)` helper.
- **ChatApiService**:
    - Access active language from `AppConfig` or `LocaleProvider`.
    - Update `inputs` in `streamChat`.

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Config    | AD-3          | T113      | Code audit   |
| FR-2: L10n System| AD-4          | T114, T116  | Widget test  |
| FR-3: API Sync  | Technical Approach| T115      | Integration test |
| FR-4: Currency  | AD-5          | T117      | Integration test |
| FR-5: Persistence| Technical Approach| T114      | Manual check |
| NFR-1: Latency  | Provider pattern | T116      | Manual check |
| NFR-2: Integrity| AD-5          | T117      | Unit test    |

## Implementation Strategy

### Phase 1: Configuration & State
- **Exit Criterion:** `LocaleProvider` is implemented, persisted, and `ChatApiService` sends the correct language.

### Phase 2: UI Localization
- **Exit Criterion:** All core UI strings are externalized and react to language changes.

### Phase 3: Currency Flow & Testing
- **Exit Criterion:** Currency switch triggers confirmation and wipe; all tests pass.

## Task Breakdown

##### T113: Define L10nConfig and initial translations
- **Phase:** 1 | **Parallel:** yes | **Est:** 1d | **Complexity:** simple
- **What:** Create `lib/configs/l10n_config.dart`. Define `AppLanguage` and `AppCurrency` enums. Create a `Map<String, Map<String, String>>` for EN/VI translations.
- **PRD requirements:** FR-1

##### T114: Implement LocaleProvider and Persistence
- **Phase:** 1 | **Parallel:** no | **Est:** 1d | **Complexity:** moderate
- **What:** Create `lib/providers/locale_provider.dart`. Handle locale/currency switching and sync with `StorageService`. Add `translate(key)` method.
- **PRD requirements:** FR-2, FR-5

##### T115: Update ChatApiService for language awareness
- **Phase:** 1 | **Parallel:** yes | **Est:** 1d | **Complexity:** simple
- **What:** Modify `streamChat` to use the current language from `AppConfig` or a passed parameter.
- **PRD requirements:** FR-3

##### T116: Localize Core UI
- **Phase:** 2 | **Parallel:** yes | **Est:** 2d | **Complexity:** simple
- **What:** Update `HomeScreen`, `ChatTab`, `RecordsTab`, and `ConfirmationDialog` to use localized strings.
- **PRD requirements:** FR-2, NFR-1

##### T117: Implement protected currency change flow
- **Phase:** 3 | **Parallel:** no | **Est:** 1d | **Complexity:** moderate
- **What:** In the Drawer, wire the currency selector to show `ConfirmationDialog`. On confirm, call `RecordProvider.resetAllData()` and then update currency.
- **PRD requirements:** FR-4, NFR-2

##### T118: Write unit and integration tests for L10n
- **Phase:** 3 | **Parallel:** yes | **Est:** 1d | **Complexity:** moderate
- **What:** Test persistence, translation lookups, and the atomic "wipe-then-switch" currency flow.
- **PRD requirements:** SC-1, SC-2, SC-3

##### T119: Integration verification & cleanup
- **Phase:** 3 | **Parallel:** no | **Est:** 1d | **Complexity:** simple
- **What:** Final quality gate for the language and currency update epic.

## Tasks Created
| #   | Task                     | Phase | Parallel | Est. | Depends On | Status |
| --- | ------------------------ | ----- | -------- | ---- | ---------- | ------ |
| 113 | Define L10nConfig and initial translations | 1     | yes      | 1d   | —          | open   |
| 114 | Implement LocaleProvider and Persistence | 1     | no       | 1d   | 113        | open   |
| 115 | Update ChatApiService for language awareness | 1     | yes      | 1d   | 114        | open   |
| 116 | Localize Core UI | 2     | yes      | 2d   | 114        | open   |
| 117 | Implement protected currency change flow | 2     | no       | 1d   | 114, 116   | open   |
| 118 | Write unit and integration tests for L10n | 3     | yes      | 1d   | 114, 117   | open   |
| 119 | Integration verification & cleanup | 3     | no       | 1d   | all        | open   |

### Summary
- **Total tasks:** 7
- **Parallel tasks:** 4
- **Sequential tasks:** 3
- **Estimated total effort:** 8d
- **Critical path:** T113 -> T114 -> T116 -> T117 -> T119 (~5d)

### Dependency Graph
```
Dependency Graph:
  T113 ──→ T114 ──→ T115
                ──→ T116 ──→ T117 ──→ T119
                ──→ T118 ─↗
```
