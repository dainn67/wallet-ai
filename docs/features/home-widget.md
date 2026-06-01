# Home Widget Feature Documentation

## Overview

The home widget provides "Add a record" affordances directly from the Android home screen without opening the app. It uses Glance composables with `SizeMode.Responsive`, mapping five `DpSize` breakpoints to progressively richer layouts. All interactions deep-link into the app via `actionStartActivity` with a `homeWidget://` URI — no overlay Activity, no `RemoteInput`.

## Layout Breakpoints

The widget renders one of five composable layouts based on the allocated `DpSize`. Per-element `clickable` bindings are applied before the root `Box.clickable` (fallback tap) so Glance's hit-test resolves inner elements first.

| Breakpoint | Size (dp)  | Bar | Label | Write icon | Camera icon | Stats              |
|------------|------------|-----|-------|------------|-------------|--------------------|
| 1×1 SMALL  | 80×80      | ✓   | —     | —          | —           | —                  |
| 1×2 TALL   | 80×160     | ✓   | —     | —          | —           | Balance            |
| 2×1 WIDE   | 160×80     | ✓   | ✓     | —          | —           | —                  |
| 2×2 MEDIUM | 160×160    | ✓   | ✓     | ✓          | ✓           | Balance + stats row |
| 3×2+ LARGE | 240×200    | ✓   | ✓     | ✓          | ✓           | Full dashboard     |

- **Bar** — `QuickRecordBar`; uses `iconOnly: true` when `size.width <= 80.dp` (SMALL and TALL).
- **Write icon** — `android.R.drawable.ic_menu_edit` (system drawable, already used in codebase); deep-links `homeWidget://record`.
- **Camera icon** — see §Camera Icon Decision below; deep-links `homeWidget://camera`.
- **Stats** — existing balance / stats composables; present on TALL through LARGE.

## Camera Icon Decision

**Decision: use `android.R.drawable.ic_menu_camera`.**

`android.R.drawable.ic_menu_camera` is a guaranteed stock system drawable on all API levels 26+ (minSdk for this project). It is handled identically to `ic_menu_edit`, which is already confirmed working in the codebase.

If T002 discovers that OEM-skinned launchers strip or replace this glyph (observed as a blank/placeholder icon), the fallback is to bundle a Material camera vector at `android/app/src/main/res/drawable/ic_camera.xml`. That decision is deferred to T002 — no vector asset is created by this task.

## ChatTab Camera Picker — Call-Site Reference (for T004)

**File:** `lib/screens/home/tabs/chat_tab.dart`
**Function:** `_pickFromCamera()` at **lines 81–89**

```dart
// lib/screens/home/tabs/chat_tab.dart:81-89
Future<void> _pickFromCamera() async {
  if (_pendingImages.length >= _maxImages) {
    _showSnackBar('Maximum 5 images per message');
    return;
  }
  final file = await ImagePickerService().pickFromCamera();
  if (!mounted || file == null) return;
  await _processAndAdd([file]);
}
```

**What it does:**
1. Guards against the 5-image-per-message cap.
2. Delegates to `ImagePickerService().pickFromCamera()` which calls `ImagePicker().pickImage(source: ImageSource.camera)` — no explicit permission request; the `image_picker` package handles OS-level camera permission prompts natively. Returns `null` on cancel or denial.
3. On success, passes the single `XFile` to `_processAndAdd(List<XFile>)` (lines 102–130), which compresses/validates each image via `ImageProcessingService` and appends the resulting `Uint8List` to `_pendingImages`.

**T004 refactor target:** Extract the body of `_pickFromCamera` into `ChatProvider.pickImageFromCamera({BuildContext? context})`. The in-app camera button (`chat_tab.dart:248-249`) becomes a thin call through to the provider method. No behavior change visible to the user.

**Button site:** `lib/screens/home/tabs/chat_tab.dart:248-249`
```dart
icon: Icon(Icons.camera_alt_outlined, ...),
onPressed: isStreaming ? null : _pickFromCamera,
```

## Deep-Link URIs

| URI                    | Action                                         |
|------------------------|------------------------------------------------|
| `homeWidget://record`  | Switch to ChatTab + focus text input           |
| `homeWidget://camera`  | Switch to ChatTab + call `ChatProvider.pickImageFromCamera()` |

Both URIs are dispatched in `lib/screens/home/home_screen.dart` inside `_handleWidgetClick(Uri?)`.

## Architecture Decisions

- **AD-1:** Plain-UI Glance composables, no overlay Activity (simplicity over premium feel).
- **AD-2:** Two distinct URIs over a single URI + query param (easier to grep; Glance `actionStartActivity` is per-clickable).
- **AD-3:** Camera trigger lives on `ChatProvider.pickImageFromCamera()` — single source of truth for both the in-app button and the widget deep-link.

## Key Files

| File | Role |
|------|------|
| `android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt` | Glance composables — rewritten in T002 |
| `lib/screens/home/home_screen.dart` | Deep-link router (`_handleWidgetClick`) — extended in T003 |
| `lib/providers/chat_provider.dart` | Camera trigger method added in T004 |
| `lib/screens/home/tabs/chat_tab.dart` | Existing camera call-site — refactored in T004 |
| `lib/services/image_picker_service.dart` | Singleton wrapping `image_picker`; `pickFromCamera()` at line 28 |
