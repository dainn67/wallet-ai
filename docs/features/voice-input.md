# Voice Input Feature Documentation

## Feature Overview

Voice Input allows users to speak an expense or income note instead of typing it. The user taps a microphone icon in the chat composer, records up to 30 seconds of audio, and taps stop — the audio is sent to the AI which transcribes and parses it into a structured record card, exactly as if the user had typed the message. This is aimed at quick capture scenarios where typing is inconvenient (e.g., driving, cooking).

## User Flow

1. **Tap mic** — user taps `Icons.mic_none_outlined` in the chat composer pill.
2. **Permission** — if microphone permission is not yet granted, a rationale dialog appears; the system permission dialog follows. If denied, a snackbar is shown and recording does not start.
3. **Recording bar** — the composer row is replaced (via `AnimatedSwitcher`) with `_RecordingBar`: a cancel button (×) on the left, an amplitude-driven mic icon in the centre, an elapsed M:SS timer, and a stop-and-send button (■) on the right.
4. **Stop** — user taps ■ or 30 seconds elapse (auto-stop). The audio bytes are passed to `ChatProvider.sendMessage(audioBytes:)`.
5. **Cancel** — user taps × — recording is cancelled with no message sent.
6. **AI response** — after the server processes the audio, the chat stream returns a text reply followed by `--//--` and a JSON array of records, exactly as with text input.
7. **Record card or error** — if records are parsed, a record card appears in the chat bubble. If the server returns an empty records array (audio not understood), the assistant message is replaced with `"I didn't catch that. Please try again."`.

## Technical Flow

```
ChatTab._onMicTap()
  └─ AudioRecordingService.start()      # starts AAC-LC 128 kbps mono recording
       └─ (user taps stop / 30 s timer)
  └─ AudioRecordingService.stop()       # returns Uint8List audio bytes
  └─ ChatProvider.sendMessage('', audioBytes: bytes)
       └─ ImageProcessingService().toBase64(bytes)   # byte-agnostic base64 encoder
       └─ ChatApiService.streamChat(audioBase64: ...)
            └─ POST /streaming  (Dify endpoint, top-level `audio` key)
                 └─ Gemini receives audio as inline base64 part
                 └─ returns "text--//--[{records_json}]"
       └─ ChatProvider._handleStream (onDone)
            └─ split by --//--
            └─ jsonDecode records array
            └─ if records.isEmpty && hadAudio → voice_didnt_catch_that
            └─ else RecordProvider.createRecord(record)  for each record
```

## Error Paths

### Voice failure
Condition: `hadAudio == true && records.isEmpty` after stream completes.
Action: `ChatProvider._handleStream` replaces the assistant message content with the translation of `voice_didnt_catch_that` (`"I didn't catch that. Please try again."` in English).
No record card is shown.

### Image failure (FR-5 retroactive)
Condition: `ImageProcessingService.processPickedImage` throws during the pick/compress flow.
Action: `ChatTab._processAndAdd` catches the exception and shows a `SnackBar` with the translation of `image_load_failed` (`"Couldn't load the image. Please try again."`). The image is not added to the pending strip.

### Microphone permission denied
Condition: `AudioRecordingService.hasPermission()` returns false.
Action: rationale `AlertDialog` shown → if user still declines, a `SnackBar` with `"Microphone access is needed to record voice notes."` appears and recording does not start.

## Constraints

- **30-second hard cap** — `AudioRecordingService` schedules an internal `Timer(30 s, _handleAutoStop)` that fires `onAutoStopped(bytes)` automatically.
- **Voice and image mutually exclusive per request** — `ChatProvider.sendMessage` accepts either `imageBytes` or `audioBytes`; `ChatTab` disables the camera/gallery attachment icon while recording is active.
- **Streaming guard** — mic icon's `onPressed` is `null` while `ChatProvider.isStreaming == true`, preventing concurrent sends.
- **Server routing deferred** — the Dify workflow currently routes audio to the same Gemini model as text/image. A dedicated audio routing node is tracked separately in `docs/server-update-voice-input.md`.

## Package Details

| Package | Version | Role |
|---|---|---|
| `record` | 5.2.1 | Audio capture; AAC-LC encoder, 128 kbps, 44 100 Hz, mono |
| `permission_handler` | 11.4.0 | Microphone permission request + status check |
| `path_provider` | ^2.1.5 | Temporary directory for `.m4a` file during recording |

## Key Files

| File | Responsibility |
|---|---|
| `lib/services/audio_recording_service.dart` | Singleton; wraps `record` package; start/stop/cancel; elapsed+amplitude streams; 30 s auto-stop timer |
| `lib/screens/home/tabs/chat_tab.dart` | UI: mic icon, `_RecordingBar`, `_onMicTap`, `_stopAndSend`, `_cancelRecording`, `_handleAutoStopped` |
| `lib/providers/chat_provider.dart` | `sendMessage(audioBytes:)` → `_handleStream`; `hadAudio` flag; voice-error detection |
| `lib/services/chat_api_service.dart` | `streamChat(audioBase64:)` — top-level `audio` key in Dify payload |
| `lib/services/image_processing_service.dart` | `toBase64()` reused for audio byte encoding |
