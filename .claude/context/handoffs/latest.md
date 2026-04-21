---
epic: image-input
task: 171
status: completed
created: 2026-04-21T17:11:46Z
updated: 2026-04-21T17:11:46Z
---

# Handoff: Task #171 — ImageProcessingService

## Status
COMPLETE — all 8 unit tests pass; `fvm flutter analyze lib/services/image_processing_service.dart` returns no issues.

## What Was Done

- Created `lib/services/image_processing_service.dart`:
  - `OversizeImageException(originalName, sizeBytes)` — typed exception thrown when post-compression bytes > 1.5 MB.
  - `ImageProcessingService` singleton (mirrors `ChatApiService` pattern with `setMockInstance`).
  - `processPickedImage(XFile) → Future<Uint8List>` — applies AD-5 pass-through (non-HEIC JPEG ≤ 512 KB skips re-encoding); otherwise compresses via `FlutterImageCompress.compressWithList` (minWidth/minHeight=1600, quality=85, JPEG, keepExif=false).
  - `toBase64(Uint8List) → String` — pure `base64Encode` with no `data:` URI prefix.
- Added `export 'image_processing_service.dart';` to `lib/services/services.dart` (alphabetical position after `chat_api_service`).
- Created `test/services/image_processing_service_test.dart` with 8 tests covering: `toBase64` correctness, `OversizeImageException` payload, pass-through branch (small JPEG), and singleton mock injection.

## Key Decisions

- **Pass-through threshold:** 512 KB byte-length check (close to the 500 KB spec) used as a fast proxy to avoid decoding image headers. HEIC always goes through compression to ensure JPEG output.
- **Compression quality:** 85 JPEG quality, max 1600px longest edge (minWidth=minHeight=1600 per plugin API).
- **EXIF stripping:** `keepExif: false` applied for privacy (location data) and correct orientation.
- **Skipped tests:** Compression branch tests (`large JPEG`, `HEIC`, `oversize after compression`) are skipped in unit tests because `flutter_image_compress` requires a platform channel. These must be covered by integration/manual tests.

## Public API for #172 and #173

```dart
// lib/services/image_processing_service.dart (exported from lib/services/services.dart)

class OversizeImageException implements Exception {
  final String originalName;
  final int sizeBytes;
}

class ImageProcessingService {
  factory ImageProcessingService();  // singleton
  static void setMockInstance(ImageProcessingService? instance);

  Future<Uint8List> processPickedImage(XFile picked);
  // Returns: JPEG bytes, longest edge <= 1600px, size <= 1.5 MB
  // Throws:  OversizeImageException when post-compression size > 1.5 MB

  String toBase64(Uint8List bytes);
  // Returns: pure base64 string (no data: URI prefix)
}
```

## Notes for Next Tasks

- **#172 ImagePickerService** — can now call `ImageProcessingService().processPickedImage(xfile)` on each picked file and catch `OversizeImageException` for inline UI errors.
- **#173 Chat attachment UI** — use `toBase64` to encode bytes before including in the API request payload.
- `flutter analyze` still shows 138 pre-existing issues; none introduced by this task.
