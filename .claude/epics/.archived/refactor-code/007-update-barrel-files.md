---
name: Update barrel files and verify file placements
status: closed
created: 2026-03-28T17:50:49Z
updated: 2026-03-28T18:32:04Z
complexity: simple
recommended_model: sonnet
phase: 3
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/143"
depends_on: [004, 005]
parallel: true
conflicts_with: []
files:
  - lib/helpers/helpers.dart
  - lib/components/components.dart
  - lib/providers/providers.dart
  - lib/services/services.dart
  - lib/models/models.dart
  - lib/repositories/repositories.dart
  - lib/configs/configs.dart
  - lib/screens/screens.dart
prd_requirements:
  - FR-5
  - FR-6
---

# Update barrel files and verify file placements

## Context

Barrel files are the single-point exports for each directory. After T4 and T5 created new component files, the barrel files need updating. Additionally, `helpers/helpers.dart` is missing the export for `currency_helper.dart`. Per FR-5, every public file must be exported and no removed files referenced.

## Description

Fix all barrel files to match their directory contents. Verify every file is in the correct directory per the layer mapping table in the PRD's Constraints section.

## Acceptance Criteria

- [ ] **FR-5 / Happy path:** `helpers/helpers.dart` exports both `api_helper.dart` and `currency_helper.dart`
- [ ] **FR-5 / Happy path:** `components/components.dart` exports `chat_bubble.dart` and `popups/add_sub_category_dialog.dart`
- [ ] **FR-5 / Happy path:** Every barrel file exports exactly the public Dart files in its directory (1:1 match)
- [ ] **FR-5 / Happy path:** No barrel file references a deleted or renamed file
- [ ] **FR-5 / File placement:** Every file resides in the directory matching its architectural role per the layer mapping table
- [ ] **FR-6 / Behavior preservation:** No runtime behavior changes — barrel file changes only affect import resolution

## Implementation Steps

### Step 1: Fix helpers barrel file

- Modify `lib/helpers/helpers.dart`
- Add: `export 'currency_helper.dart';`
- Current state: only exports `api_helper.dart`

### Step 2: Update components barrel file

- Modify `lib/components/components.dart`
- Add: `export 'chat_bubble.dart';` (created in T4)
- Add: `export 'popups/add_sub_category_dialog.dart';` (created in T5)
- Verify all existing exports are still valid

### Step 3: Verify all barrel files

For each barrel file, compare exports to directory contents:

| Barrel File | Expected Exports |
|-------------|-----------------|
| `providers/providers.dart` | chat_provider, record_provider, locale_provider |
| `services/services.dart` | api_exception, api_service, chat_api_service, storage_service, toast_service |
| `models/models.dart` | category, chat_message, chat_stream_response, money_source, record |
| `repositories/repositories.dart` | record_repository |
| `configs/configs.dart` | app_config, chat_config, l10n_config |
| `helpers/helpers.dart` | api_helper, currency_helper |
| `components/components.dart` | category_widget, record_widget, records_overview, month_divider, chat_bubble + all popups |
| `screens/screens.dart` | Check current content matches actual screen files |

### Step 4: Audit file placements

Review each file against the layer mapping table:
- Models: only data classes, no logic → ✓
- Repositories: only data persistence → ✓
- Services: stateless utilities → ✓
- Helpers: pure functions → ✓
- Providers: state management + orchestration → ✓ (after T1/T2)
- Components: reusable UI → ✓ (after T4/T5)
- Screens: page-level widgets → ✓

## Technical Details

- **Approach:** Per FR-5, barrel files must be 1:1 with directory contents
- **Files to modify:** `lib/helpers/helpers.dart`, `lib/components/components.dart`
- **Files to verify:** All other barrel files
- **Edge cases:**
  - Adding `currency_helper.dart` to the helpers barrel may trigger unused import warnings in files that import `helpers.dart` but don't use `CurrencyHelper`. Run `flutter analyze` to check.
  - `screens/screens.dart` — verify it exports home_screen correctly

## Tests to Write

### Unit Tests
- No tests needed — barrel file changes are cosmetic

## Verification Checklist

- [ ] `flutter analyze` passes with zero errors
- [ ] `grep "currency_helper" lib/helpers/helpers.dart` shows the export
- [ ] `grep "chat_bubble" lib/components/components.dart` shows the export
- [ ] `grep "add_sub_category_dialog" lib/components/components.dart` shows the export
- [ ] Manual verify: each barrel file's exports match `ls` of its directory
- [ ] No file is misplaced per layer mapping table

## Dependencies

- **Blocked by:** T4, T5 (new files must exist before adding to barrel)
- **Blocks:** T8 (final audit)
- **External:** None
