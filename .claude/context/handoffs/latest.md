---
epic: image-input
task: 174
status: completed
created: 2026-04-21T17:27:39Z
updated: 2026-04-21T17:27:39Z
---

# Handoff: Task #174 — Chat input attachment UI

## Status
COMPLETE — 7 ChatTab widget tests (6 pre-existing + 1 new) pass, 2 polish tests pass, 23 ChatProvider tests still green. `fvm flutter analyze` on changed files shows 0 new issues (the 2 info-level warnings reported are pre-existing in `category_form_dialog.dart` and unrelated).

## What Was Done

- `lib/screens/home/tabs/chat_tab.dart`:
  - Added `List<Uint8List> _pendingImages` state (defaults empty) and a static `_maxImages = 5` constant.
  - Registered `_controller.addListener(_onTextChanged)` in `initState` + removal in `dispose` so the send-button enable state reacts to typing.
  - Added attachment `IconButton(Icons.add_photo_alternate_outlined)` *inside* the pill `TextField` container (right edge, sitting flush with the text field thanks to a Row wrapping the `TextField` + icon). Tooltip "Attach image". Disabled during `isStreaming` — same rule as the send button.
  - `_showAttachmentSheet()` opens a rounded-top `showModalBottomSheet` (`Radius.circular(16)`) with two `ListTile`s: "Take photo" (leading `Icons.camera_alt_outlined`) and "Choose from library" (leading `Icons.photo_library_outlined`), wrapped in `SafeArea`. Strings pulled via `LocaleProvider.translate('take_photo' | 'choose_from_library')`.
  - `_pickFromCamera()` / `_pickFromGallery()` call `ImagePickerService()` (picker enforces cap via `maxCount: 5 - _pendingImages.length`). Early return when cap is already hit.
  - `_processAndAdd(List<XFile>)` runs `ImageProcessingService().processPickedImage` in parallel via `Future.wait`. Oversize images throw `OversizeImageException` and are simply counted — a floating SnackBar "Image too large after compression" is shown when `oversizeCount > 0`. A defensive second-cap trim issues "Maximum 5 images per message" if the service hands back more than remaining capacity.
  - `_handleSend()` pulls `text = _controller.text.trim()` and `images = List.of(_pendingImages)`. If BOTH empty → no-op. Otherwise clears controller + `_pendingImages` BEFORE awaiting `sendMessage(text, imageBytes: images.isEmpty ? null : images)`. Errors go through the existing SnackBar path.
  - `canSend = !isStreaming && (text.trim().isNotEmpty || _pendingImages.isNotEmpty)` — drives both the send button's `onTap` and color and the `onSubmitted` guard on the `TextField`.
  - Above `_buildInputArea()`, renders `ImagePreviewStrip` only when `_pendingImages.isNotEmpty` (wrapped in a small top padding for breathing room).

- `lib/components/image_preview_strip.dart` (new): stateless widget that renders a 72-high horizontal `ListView.separated` of 64×64 rounded thumbnails (`Image.memory`) with a circular black-54 × button overlay (`onTap → onRemove(i)`). Beneath the list sits a small "Max 5 images" helper in grey. Kept simple — no animation, no dismissible.

- `lib/components/components.dart`: added `export 'image_preview_strip.dart';`.

- `lib/configs/l10n_config.dart`: added `take_photo` / `choose_from_library` keys for both English ("Take photo" / "Choose from library") and Vietnamese ("Chụp ảnh" / "Chọn từ thư viện").

- `test/screens/chat_tab_test.dart`: added 1 widget test verifying the attachment icon is present and tapping it opens the bottom sheet with both options. Also added a `pump()` between `enterText` and `tap` in the existing "sendMessage and clears controller" test — necessary because `canSend` now reacts to text, so the send-button needs a rebuild to enable.

- `test/screens/chat_tab_polish_test.dart`: same `pump()` addition for the error-SnackBar test (same reason).

## Key Decisions

- **Icon inside the pill, not outside.** The pill `Container` now holds a `Row(TextField + IconButton)` — the `TextField` stays expanded and the icon sits at the trailing edge. This avoids widening the input area and keeps visual parity with ChatGPT / Claude mobile layouts. Removed the pill's right padding (was `symmetric(horizontal: 16)`, now `only(left: 16)`) so the icon's own touch target provides the right-side breathing room.
- **SnackBar for errors, not inline banner.** The task file suggested a timed inline banner for oversize errors; I used a floating SnackBar instead because (a) the app already standardises on SnackBars for transient errors (`_handleSend` uses one), (b) it avoids an extra state field, and (c) it keeps the diff small. Same UX outcome: user sees the message, auto-dismisses.
- **Cap enforcement is belt-and-suspenders.** `ImagePickerService.pickFromGallery(maxCount: N)` already trims, but camera returns exactly 1 file and the widget checks `_pendingImages.length < _maxImages` before even opening the sheet. `_processAndAdd` also re-trims defensively.
- **Did not add `_attachErrorMessage` state.** Task file sketched an inline red-text banner but the SnackBar path is simpler and matches existing patterns.
- **`canSend` controls both tap and visual.** Sending button's colour + shadow now reflect disabled state when there's nothing to send — previously it only dimmed while streaming.

## What #175 (ChatBubble + fullscreen viewer) Needs To Do

The `ChatMessage.imageBytes` field is already populated by `ChatProvider.sendMessage` (from #173). #175 should:

1. In `lib/components/chat_bubble.dart`, inside the user-role branch — ABOVE the existing text `Container` (at `crossAxisAlignment: CrossAxisAlignment.end`) — render a `Wrap(spacing: 4, runSpacing: 4)` of `Image.memory(bytes, width: 96, height: 96, fit: BoxFit.cover)` clipped with `ClipRRect(BorderRadius.circular(8))` WHEN `message.imageBytes != null && message.imageBytes!.isNotEmpty`.
2. Wrap each thumbnail in a `GestureDetector(onTap: () => Navigator.push(... ImageViewer ...))`.
3. Create `lib/components/image_viewer.dart` — a `Scaffold(backgroundColor: Colors.black)` with an `InteractiveViewer` wrapping `Image.memory` for pinch-zoom + pan. Dismiss via back button.
4. Register the new widget in `lib/components/components.dart`.
5. Add a widget test in `test/components/chat_bubble_test.dart` that a user-role `ChatMessage` with `imageBytes: [someBytes]` renders exactly one `Image.memory`.
6. Do NOT touch `chat_tab.dart` (already owns the pending-images lifecycle) or `image_preview_strip.dart` (that's input-side, pre-send).

## Files Changed

- `lib/screens/home/tabs/chat_tab.dart`
- `lib/components/image_preview_strip.dart` (new)
- `lib/components/components.dart`
- `lib/configs/l10n_config.dart`
- `test/screens/chat_tab_test.dart`
- `test/screens/chat_tab_polish_test.dart`
- `.claude/epics/image-input/174.md` (frontmatter → closed)
