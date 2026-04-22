# Handoff: Task #184 — error strings + image error snackbar
Completed: 2026-04-22T12:32:33Z

## What was done
- Added `voice_didnt_catch_that` and `image_load_failed` l10n keys to both English and Vietnamese blocks in `lib/configs/l10n_config.dart`
- Added `failCount` tracking in `_processAndAdd` in `chat_tab.dart`; when any non-oversize exception fires during image processing, shows a localized snackbar via `l10n.translate('image_load_failed')`

## Files changed
- `lib/configs/l10n_config.dart` — 4 new key/value entries (2 per language)
- `lib/screens/home/tabs/chat_tab.dart` — added `failCount` tracking and localized snackbar in `_processAndAdd` catch block (~10 lines added)
- `.claude/epics/voice-input/184.md` — status closed
- `.claude/context/handoffs/latest.md` — this file

## Decisions
- EN `voice_didnt_catch_that`: "I didn't catch that. Please try again."
- VN `voice_didnt_catch_that`: "Mình chưa nghe rõ. Bạn thử lại nhé."
- EN `image_load_failed`: "Couldn't load the image. Please try again."
- VN `image_load_failed`: "Không tải được ảnh. Bạn thử lại nhé."
- Surfacing pattern: `context.read<LocaleProvider>().translate(key)` — mirrors how `_showAttachmentSheet` reads l10n in the same file
- Keys placed at the end of each language block (no strict alphabetical order observed in existing file)

## Key strings for downstream tasks
- voice_didnt_catch_that (used by #183 ChatProvider for voice-failure UI)
- image_load_failed (already surfaced here in chat_tab.dart `_processAndAdd` catch block, ~line 178)

## Warnings for next tasks
- `chat_tab.dart` now has `failCount` + snackbar in `_processAndAdd` (lines ~148–178). Task #181's mic-icon addition should sit beside the camera icon in the build method widget tree — do NOT touch `_processAndAdd` unless intentionally extending image error handling.
- The `formatCategories` test in `test/services/chat_api_service_formatting_test.dart` was already failing before this task (pre-existing semicolon vs comma mismatch). Not caused by task #184.
