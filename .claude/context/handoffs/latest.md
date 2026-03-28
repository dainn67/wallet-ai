# Handoff Notes: Task #006 - Standardize import ordering across all files

## What was done
Applied AD-4 import ordering convention across all Dart files in lib/.

## Convention applied
- Group order: `dart:` → `package:flutter/` → `package:third_party/` → `package:wallet_ai/` → relative (same-dir)
- Blank line between each group, alphabetical within each group
- Cross-directory references converted to package imports
- Same-directory references use relative imports (barrel files remain relative)

## Files Changed (20 lib/ files)
- `lib/providers/chat_provider.dart` — fixed `../configs/configs.dart` → package import, added groups
- `lib/providers/locale_provider.dart` — fixed `../configs/l10n_config.dart`, `../services/storage_service.dart` → package imports
- `lib/providers/record_provider.dart` — reordered (home_widget moved to third-party group)
- `lib/screens/home/home_screen.dart` — fixed `../../configs/`, `../../providers/`, `../../components/`, tabs → package imports
- `lib/screens/home/tabs/categories_tab.dart` — fixed `../../../providers/`, `../../../components/`, `../../../models/` → package imports
- `lib/screens/home/tabs/chat_tab.dart` — added blank lines between groups
- `lib/screens/home/tabs/records_tab.dart` — reordered (intl/provider to third-party group)
- `lib/screens/home/tabs/test_tab.dart` — reordered (home_widget to third-party group)
- `lib/components/category_widget.dart` — fixed `../models/`, `../helpers/`, `../services/` → package imports
- `lib/components/chat_bubble.dart` — fixed same-dir record_widget to relative, added groups
- `lib/components/record_widget.dart` — reordered (intl/provider to third-party group)
- `lib/components/records_overview.dart` — reordered, removed pre-existing unused storage_service import
- `lib/components/popups/add_source_popup.dart` — fixed `../../models/`, `../../providers/` → package imports
- `lib/components/popups/add_sub_category_dialog.dart` — fixed `../../models/`, `../../providers/` → package imports
- `lib/components/popups/category_form_dialog.dart` — fixed `../../providers/`, `../../models/` → package imports
- `lib/components/popups/edit_record_popup.dart` — fixed `../../models/`, `../../providers/` → package imports
- `lib/components/popups/edit_source_popup.dart` — fixed `../../models/`, `../../providers/` → package imports
- `lib/helpers/currency_helper.dart` — fixed `../services/storage_service.dart` → package import
- `lib/configs/app_config.dart` — reordered (flutter moved to flutter group)
- `lib/models/chat_message.dart` — fixed same-dir record.dart to relative import
- `lib/services/chat_api_service.dart` — fixed same-dir api_exception/api_service to relative imports
- `lib/main.dart` — reordered (flutter_dotenv/home_widget/provider to third-party group)

## Verification
- `fvm flutter analyze lib/` — 0 errors, 0 warnings (28 pre-existing infos: avoid_print, use_build_context_synchronously, deprecated_member_use)
- `grep -rn "'\.\./" lib/` — zero results (no relative cross-directory imports remain)
- `grep -rn "'\.\./..\/" lib/` — zero results

## Key Decisions
- Same-directory imports remain relative (e.g., `record_provider.dart` within providers/, `confirmation_dialog.dart` within popups/)
- `records_overview.dart` → `popups/add_source_popup.dart` kept as relative (subdirectory of same component group) — placed in last group
- Removed pre-existing unused `storage_service.dart` import from `records_overview.dart` (was a warning before, now cleaned)

## Warnings for Next Task
- No issues. All imports now follow AD-4 convention. Pre-existing infos (avoid_print etc.) are unrelated to this task.
