# Handoff: Task #180 — AudioRecordingService singleton
Completed: 2026-04-22T12:28:34Z

## What was done
- Created `lib/services/audio_recording_service.dart` as a singleton wrapping `record` 5.2.1 (`AudioRecorder`) and `permission_handler` 11.x (`Permission.microphone`)
- Implemented full public API: `hasPermission()`, `start()`, `stop()`, `cancel()`, `elapsedStream`, `amplitudeStream`, `onAutoStopped()`
- Added export to `lib/services/services.dart`
- `fvm flutter analyze` reports zero issues on the new file

## Files changed
- `lib/services/audio_recording_service.dart` — new file (service singleton)
- `lib/services/services.dart` — added `export 'audio_recording_service.dart';`
- `.claude/epics/voice-input/180.md` — status: open → closed

## Decisions
- **Bit rate:** 128 kbps AAC-LC mono, 44100 Hz — yields ~480 KB for 30 s (within NFR-1 500 KB cap)
- **Channel count:** 1 (mono) — sufficient for voice, halves file size vs stereo
- **Amplitude normalization:** `-45..0 dBFS` floor → `0.0..1.0` linear. Formula: `((current - (-45)) / 45).clamp(0.0, 1.0)`. Polled every 200 ms via our own `Timer` calling `_recorder.getAmplitude()` (not `onAmplitudeChanged` which requires a listener to stay active)
- **Temp file naming:** `audio_<epochMillis>.m4a` in `getTemporaryDirectory()` — `path_provider` is a direct dep (confirmed in pubspec.yaml)
- **start() while recording:** no-op with `debugPrint` warning (not a throw) — keeps UI safe on rapid double-tap
- **Permission check in start():** uses `Permission.microphone.request()` via `permission_handler` (not `_recorder.hasPermission()`) for explicit OS-level permission request before recording begins
- **onAutoStopped registration:** `void onAutoStopped(callback)` method (not a setter property) — aligns with task spec

## Public API reference (for #181/#182/#183)

```dart
// Singleton
AudioRecordingService()  // factory, returns same instance

// Permission
Future<bool> hasPermission()

// Control
Future<void> start()         // throws StateError('Microphone permission denied') if denied
Future<Uint8List?> stop()    // returns null if not recording; catches file errors
Future<void> cancel()        // no-op if not recording

// Streams (broadcast)
Stream<Duration> get elapsedStream    // emits every 200 ms while recording
Stream<double> get amplitudeStream    // emits 0.0..1.0 normalized every 200 ms

// Auto-stop callback
void onAutoStopped(void Function(Uint8List? bytes) callback)
// call BEFORE start(); fires when 30-s timer elapses; bytes may be null on error
```

## Warnings for next tasks
- **#181 (UI):** Register `onAutoStopped` callback BEFORE calling `start()`. The callback receives `Uint8List?` directly — UI should forward bytes to the provider's send method.
- **#181 (UI):** `amplitudeStream` emits `double` (0..1), NOT `Amplitude` — UI can use directly for waveform animation without additional conversion.
- **#182 (API):** `stop()` returns raw `Uint8List` — API layer must base64-encode before attaching to the chat request payload.
- **#183 (Provider):** `stop()` is safe to call even if not recording (returns null). Provider should check for null before attempting to send.
- **Pre-existing test failure:** `chat_api_service_formatting_test.dart` has one failing test (comma vs semicolon separator) that pre-dates this task — not caused by these changes.
