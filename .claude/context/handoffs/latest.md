# Handoff: Task #179 — record + permission_handler deps + platform plumbing
Completed: 2026-04-22T12:13:53Z

## What was done
- Added `record: ^5.0.0` and `permission_handler: ^11.0.0` to `pubspec.yaml` under `dependencies` (alphabetically after `image_picker`)
- Added `NSMicrophoneUsageDescription` key to `ios/Runner/Info.plist` alongside existing camera/photo library keys
- Added `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` to `android/app/src/main/AndroidManifest.xml` alongside existing INTERNET and CAMERA permissions
- Ran `fvm flutter pub get` — resolved successfully
- Ran `fvm flutter analyze` — 138 pre-existing issues only, zero new errors from this task

## Files changed
- `pubspec.yaml` — added `permission_handler: ^11.0.0` and `record: ^5.0.0`
- `pubspec.lock` — updated with resolved versions
- `ios/Runner/Info.plist` — added `NSMicrophoneUsageDescription`
- `android/app/src/main/AndroidManifest.xml` — added `RECORD_AUDIO` permission
- `.claude/epics/voice-input/179.md` — frontmatter updated to closed

## Decisions
- `record` locked to **5.2.1** (newest satisfying `^5.0.0`; `^6.x` is available but out of range)
- `permission_handler` locked to **11.4.0** (newest satisfying `^11.0.0`; `^12.x` is available but out of range)
- `NSMicrophoneUsageDescription` string: "WalletAI uses the microphone to let you speak expenses instead of typing." — consistent with the task spec's suggested string and matches the app's user-facing tone

## Warnings for next task (#180 AudioRecordingService)
- `record 5.2.1` is the API in use — NOT `record ^6.x`. The `AudioRecorder` class is the primary entry point in v5. Use `AudioRecorder()`, `start(RecordConfig(...), path: ...)` and `stop()` — NOT the older static API from v4 or any v6 renames.
- `permission_handler 11.4.0` uses `Permission.microphone.request()` — same pattern as v10.
- Both packages resolve cleanly with no transitive conflicts in this project's dependency graph.
- `record_linux 0.7.2` is a transitive dep — ignore for mobile-only targets.
