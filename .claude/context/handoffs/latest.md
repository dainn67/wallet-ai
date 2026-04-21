---
epic: image-input
task: 173
status: completed
created: 2026-04-21T17:21:04Z
updated: 2026-04-21T17:21:04Z
---

# Handoff: Task #173 — Model, provider, and API payload wiring

## Status
COMPLETE — 23 ChatProvider tests (18 pre-existing + 5 new), 4 ChatApiService tests pass. Image-input suites (171/172) still green. `fvm flutter analyze` shows 0 new issues on the changed files.

## What Was Done

- `lib/models/chat_message.dart`: added transient `List<Uint8List>? imageBytes` (imports `dart:typed_data`). Wired through the named constructor and `copyWith`. Explicitly NOT added to `toJson`/`fromJson` — there is a code comment documenting the transient decision (AD-4, mirrors `Record.suggestedCategory`).
- `lib/services/chat_api_service.dart`: `streamChat(...)` now takes optional `List<String>? imagesBase64`. When non-null and non-empty, it is written as a TOP-LEVEL `images` key on the outbound body (AD-2 — sibling of `query`, NOT nested inside `inputs`). Empty / null → key omitted; byte-for-byte identical to the previous text-only payload.
- `lib/providers/chat_provider.dart`: `sendMessage(String content, {List<Uint8List>? imageBytes})`. Empty-buffer entries are filtered out. No-op guard blocks only when BOTH caption and images are empty (AD-6). Private `_handleStream` also took a matching `imageBytes` param and encodes via `ImageProcessingService().toBase64` just before calling `streamChat`. All streaming / parsing / onError logic untouched.
- `lib/services/api_service.dart`: added `setMockInstance` + `forTesting` constructor to `ApiService` following the existing `ChatApiService` pattern. This is what enables unit-testing the outbound `streamChat` body without hitting the network.
- `test/services/chat_api_service_test.dart` (new): 4 tests verifying body shape across null / empty / non-empty / empty-caption-plus-images permutations. Mocks `ApiService` via the new `setMockInstance`.
- `test/providers/chat_provider_test.dart`: added `image attachments (image-input epic)` group — 5 tests covering the transient `toJson`, no-op guard, backward-compat (no images), happy path with base64 encoding, and empty-caption-with-images.

## Key Decisions

- **Added `ApiService.setMockInstance`** so the ChatApiService body shape could be tested hermetically. The task rule "Do NOT hit network" combined with "Use existing mock patterns (`setMockInstance` on services)" made this the cleanest path — and it matches the pattern already in `ChatApiService`, `ImagePickerService`, `ImageProcessingService`, `AiPatternService`.
- **Empty-buffer filtering in `sendMessage`.** `imageBytes?.where((b) => b.isNotEmpty).toList()` trims degenerate entries before deciding if images are "present." Prevents a list of only-empty-buffers from counting as attached images (AD-6 edge).
- **`imageBytes` attached on the `ChatMessage`** at send time so UI (#175) can render thumbnails from `Image.memory` without re-reading files. Bytes live only in the in-memory `_messages` list — never written anywhere.
- **Did not touch `_handleStream`'s stream listener.** onData / onDone / onError are byte-identical. Server response parsing is unchanged; the server returns the same record-array JSON regardless of whether images were in the request.

## Public API for #174 and #175

```dart
// lib/providers/chat_provider.dart
Future<void> sendMessage(
  String content, {
  List<Uint8List>? imageBytes,     // NEW — compressed JPEG byte lists
});
```

```dart
// lib/services/chat_api_service.dart
Stream<ChatStreamResponse> streamChat(
  String message, {
  String? conversationId,
  String? categoryList,
  String? moneySourceList,
  String language = 'English',
  String currency = 'USD',
  String? pattern,
  List<String>? imagesBase64,      // NEW — already base64-encoded strings
});
```

```dart
// lib/models/chat_message.dart
class ChatMessage {
  final List<Uint8List>? imageBytes;  // NEW — transient, not in toJson/fromJson
  ChatMessage({..., this.imageBytes});
  ChatMessage copyWith({..., List<Uint8List>? imageBytes});
}
```

## How #174 (Chat input UI) Should Consume This

1. Track a local `List<Uint8List> _pendingImages` in `chat_tab.dart` state.
2. On picker return, run each `XFile` through `ImageProcessingService().processPickedImage(xfile)` via `Future.wait`; append successful `Uint8List` results to `_pendingImages`.
3. In the send handler:
   ```dart
   context.read<ChatProvider>().sendMessage(
     _controller.text,
     imageBytes: _pendingImages.isEmpty ? null : List.of(_pendingImages),
   );
   _pendingImages.clear();
   _controller.clear();
   ```
4. The provider does the remaining filtering — safe to pass a defensive copy.
5. Send button should enable when `controller.text.isNotEmpty || _pendingImages.isNotEmpty`.

## How #175 (Bubble rendering) Should Consume This

```dart
// In chat_bubble.dart, for ChatRole.user messages:
if (message.imageBytes != null && message.imageBytes!.isNotEmpty) {
  Wrap(
    children: [
      for (final b in message.imageBytes!)
        GestureDetector(
          onTap: () => openFullscreen(b),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(b, width: 96, height: 96, fit: BoxFit.cover),
          ),
        ),
    ],
  );
}
```

No null-safety concerns for assistant bubbles — `imageBytes` is only set on outgoing user messages.

## Prior Task APIs Still in Play

```dart
// From #172
class ImagePickerService {
  Future<XFile?> pickFromCamera();
  Future<List<XFile>> pickFromGallery({int maxCount = 5});
}

// From #171
class ImageProcessingService {
  Future<Uint8List> processPickedImage(XFile picked);  // throws OversizeImageException
  String toBase64(Uint8List bytes);
}
```
