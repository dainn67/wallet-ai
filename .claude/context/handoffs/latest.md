---
epic: image-input
task: 172
status: completed
created: 2026-04-21T17:14:46Z
updated: 2026-04-21T17:14:46Z
---

# Handoff: Task #172 — ImagePickerService

## Status
COMPLETE — 7 unit tests pass; `fvm flutter analyze` returns no issues for service + test files. #171 regression: 8 tests still pass.

## What Was Done

- Created `lib/services/image_picker_service.dart`:
  - Singleton pattern with `_internal()` and `setMockInstance(ImagePickerService?)` (mirrors `ImageProcessingService` exactly).
  - Added `forTesting()` named constructor (`@visibleForTesting`) so test subclasses can extend without reaching private `_internal()`.
  - `pickFromCamera() → Future<XFile?>` — delegates to `_picker.pickImage(source: ImageSource.camera)`; null on cancel or permission denial.
  - `pickFromGallery({int maxCount = 5}) → Future<List<XFile>>` — calls `_picker.pickMultiImage()` then `.take(maxCount)`. Cap is always client-side so it works on all OS versions.
- Added `export 'image_picker_service.dart';` to `lib/services/services.dart` (alphabetical: after `chat_api_service`, before `image_processing_service`).
- Created `test/services/image_picker_service_test.dart` with 7 tests using a `_FakePickerService` subclass (no platform channel required).

## Key Decisions

- **5-cap location:** `.take(maxCount)` in `pickFromGallery`. The UI (T020) passes `5 - currentAttachmentCount` as `maxCount` so cumulative total stays ≤ 5.
- **No permission code:** AD-3 — `image_picker` triggers native prompts on first use; no `permission_handler` added.
- **`forTesting()` constructor:** needed because `_internal()` is private and Dart prevents subclassing a class that only has private constructors.
- **Skipped tests:** Real camera/gallery calls require a platform channel and are not tested in unit tests. Cover in integration/manual QA (T090).

## Public API for #173 / #174

```dart
// lib/services/image_picker_service.dart (exported from lib/services/services.dart)

class ImagePickerService {
  factory ImagePickerService();  // singleton; returns mock if setMockInstance was called

  static void setMockInstance(ImagePickerService? instance);  // test injection

  Future<XFile?> pickFromCamera();
  // Returns: XFile on success, null on cancel or permission denial

  Future<List<XFile>> pickFromGallery({int maxCount = 5});
  // Returns: list of XFile (length <= maxCount), empty list on cancel
}
```

## Mock Pattern (for T020 tests)

```dart
// Extend with forTesting() constructor, override the two pick methods:
class MockImagePickerService extends ImagePickerService {
  MockImagePickerService() : super.forTesting();

  @override
  Future<XFile?> pickFromCamera() async => /* your stub */;

  @override
  Future<List<XFile>> pickFromGallery({int maxCount = 5}) async => /* your stub */;
}

// In test setUp:
ImagePickerService.setMockInstance(MockImagePickerService());
// In tearDown:
ImagePickerService.setMockInstance(null);
```

## Prior Task API (from #171)

```dart
// lib/services/image_processing_service.dart

class OversizeImageException implements Exception {
  final String originalName;
  final int sizeBytes;
}

class ImageProcessingService {
  factory ImageProcessingService();
  static void setMockInstance(ImageProcessingService? instance);

  Future<Uint8List> processPickedImage(XFile picked);
  // Throws: OversizeImageException when post-compression size > 1.5 MB

  String toBase64(Uint8List bytes);
  // Returns: pure base64 string (no data: URI prefix)
}
```
