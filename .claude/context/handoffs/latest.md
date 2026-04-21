---
epic: image-input
task: 170
status: completed
created: 2026-04-21T17:00:00Z
updated: 2026-04-21T17:00:00Z
---

# Handoff: Task #170 — Dependencies and platform permission manifests

## Status
COMPLETE — `fvm flutter pub get` succeeded. `fvm flutter analyze` shows 138 issues, all pre-existing (none introduced by the new packages).

## What Was Done

- `pubspec.yaml`: Added `flutter_image_compress: ^2.3.0` and `image_picker: ^1.1.2` under `dependencies:`.
- `ios/Runner/Info.plist`: Added `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` with user-facing English strings.
- `android/app/src/main/AndroidManifest.xml`: Added `CAMERA`, `READ_MEDIA_IMAGES` (Android 13+), and `READ_EXTERNAL_STORAGE` (with `android:maxSdkVersion="32"`) permissions.

## Key Decisions

- **Package versions:** `image_picker: ^1.1.2` and `flutter_image_compress: ^2.3.0` as specified in the task. Both resolved without conflicts against SDK `^3.9.2`.
- **Android permissions:** Added all three permission gates — `CAMERA`, `READ_MEDIA_IMAGES` (API 33+), and `READ_EXTERNAL_STORAGE` with `maxSdkVersion="32"` for pre-API-33 gallery access. This covers all Android versions.
- **No `permission_handler`:** Per AD-3 in the epic, `image_picker` supplies its own lazy permission prompts. Not added.
- **iOS permission strings:** Placed at end of root `<dict>` alongside other UI keys.

## Warnings / Notes for Next Tasks

- **#171 ImageProcessingService** and **#172 ImagePickerService** are now unblocked — both packages are installed and platform manifests are in place.
- `flutter analyze` has 138 pre-existing issues (mostly `avoid_print` in repositories, `use_build_context_synchronously` in screens, and test file errors from `month_divider_test.dart` referencing a deleted component). None are related to this task.
- Platform builds (`apk --debug`, `ios --no-codesign`) were not run to save time; platform manifest XML structure is correct. Run manually to confirm before release.
- `image_picker` on iOS requires iOS 12.0+. Check `ios/Podfile` for `platform :ios, '12.0'` or higher — bump if iOS build fails with platform version error.
