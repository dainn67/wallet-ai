---
name: Standardize import ordering across all files
status: closed
created: 2026-03-28T17:50:49Z
updated: 2026-03-28T18:30:22Z
complexity: simple
recommended_model: sonnet
phase: 3
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/142"
depends_on: [001, 002, 003, 004, 005]
parallel: true
conflicts_with: []
files:
  - lib/providers/chat_provider.dart
  - lib/providers/record_provider.dart
  - lib/providers/locale_provider.dart
  - lib/screens/home/home_screen.dart
  - lib/screens/home/tabs/chat_tab.dart
  - lib/screens/home/tabs/records_tab.dart
  - lib/screens/home/tabs/categories_tab.dart
  - lib/screens/home/tabs/test_tab.dart
  - lib/components/records_overview.dart
  - lib/components/record_widget.dart
  - lib/components/category_widget.dart
  - lib/components/month_divider.dart
  - lib/components/chat_bubble.dart
  - lib/components/popups/edit_record_popup.dart
  - lib/components/popups/add_source_popup.dart
  - lib/components/popups/edit_source_popup.dart
  - lib/components/popups/category_form_dialog.dart
  - lib/components/popups/currency_selection_popup.dart
  - lib/components/popups/confirmation_dialog.dart
  - lib/components/popups/add_sub_category_dialog.dart
  - lib/services/api_service.dart
  - lib/services/chat_api_service.dart
  - lib/services/storage_service.dart
  - lib/services/toast_service.dart
  - lib/services/api_exception.dart
  - lib/helpers/api_helper.dart
  - lib/helpers/currency_helper.dart
  - lib/configs/app_config.dart
  - lib/configs/chat_config.dart
  - lib/configs/l10n_config.dart
  - lib/models/record.dart
  - lib/models/category.dart
  - lib/models/money_source.dart
  - lib/models/chat_message.dart
  - lib/models/chat_stream_response.dart
  - lib/repositories/record_repository.dart
  - lib/main.dart
prd_requirements:
  - FR-4
  - FR-6
---

# Standardize import ordering across all files

## Context

Files use mixed import styles: some use package imports (`package:wallet_ai/...`), others use relative imports (`../configs/configs.dart`). There's no consistent grouping. Per AD-4 and FR-4, all files must follow the same convention.

## Description

Apply the AD-4 import ordering convention across all Dart files: `dart:` → `package:flutter/` → `package:third_party/` → `package:wallet_ai/` → relative imports. Use package imports for cross-directory references and relative imports only within the same directory. Add blank lines between each group.

## Acceptance Criteria

- [ ] **FR-4 / Happy path:** All Dart files in `lib/` follow the import ordering convention: dart → flutter → third-party → wallet_ai → relative, with blank lines between groups
- [ ] **FR-4 / Happy path:** No file uses relative imports to reference files in a different directory (e.g., no `../../providers/...`)
- [ ] **FR-4 / Happy path:** Relative imports are only used for files in the same directory (e.g., `import 'record_provider.dart';` within providers/)
- [ ] **FR-6 / Behavior preservation:** No runtime behavior changes — imports are cosmetic

## Implementation Steps

### Step 1: Fix chat_provider.dart imports (example of mixed style)

Current:
```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/services.dart';
import 'package:wallet_ai/repositories/record_repository.dart';  // removed in T1
import '../configs/configs.dart';  // ← relative cross-directory
import 'record_provider.dart';    // ← relative same-directory (OK)
import 'locale_provider.dart';    // ← relative same-directory (OK)
```

After:
```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/services.dart';

import 'locale_provider.dart';
import 'record_provider.dart';
```

### Step 2: Apply convention to all files

- Process files directory by directory: providers → screens → components → services → helpers → configs → models → repositories → main.dart
- For each file: sort imports into groups, replace relative cross-directory imports with package imports, add blank lines between groups
- Run `flutter analyze` after each directory batch to catch errors early

### Step 3: Verify no functional changes

- Run `flutter analyze` — must pass
- Spot-check that import resolution hasn't changed (same classes resolved)

## Technical Details

- **Approach:** Per AD-4, standardize import ordering
- **Convention:**
  1. `dart:` core libraries
  2. `package:flutter/` and `package:flutter_*/`
  3. `package:*` third-party (provider, intl, sqflite, etc.)
  4. `package:wallet_ai/` project packages (cross-directory)
  5. Relative imports (same directory only)
  - Blank line between each group. Alphabetical within each group.
- **Key violations found:**
  - `chat_provider.dart`: `../configs/configs.dart` → should be `package:wallet_ai/configs/configs.dart`
  - `locale_provider.dart`: `../configs/l10n_config.dart`, `../services/storage_service.dart` → package imports
  - `home_screen.dart`: `../../configs/configs.dart`, `../../providers/providers.dart` → package imports
  - `categories_tab.dart`: `../../../providers/providers.dart` → package import
- **Edge cases:** Barrel files (e.g., `components.dart`) use relative exports — these are same-directory so they stay relative

## Tests to Write

### Unit Tests
- No tests needed — import ordering is cosmetic with no behavior change

## Verification Checklist

- [ ] `flutter analyze` passes with zero errors
- [ ] `grep -rn "'\.\./\.\." lib/` returns zero results (no multi-level relative imports)
- [ ] `grep -rn "'\.\.\/" lib/` returns only same-directory barrel file exports or zero results
- [ ] Spot-check: 5 random files follow the convention

## Dependencies

- **Blocked by:** T1-T5 (all code moves complete before restyling imports)
- **Blocks:** T8 (final audit)
- **External:** None
