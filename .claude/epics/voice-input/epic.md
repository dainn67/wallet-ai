---
name: voice-input
status: completed
created: 2026-04-22T11:48:06Z
updated: 2026-04-22T15:30:00Z
progress: 100%
priority: P1
prd: .claude/prds/voice-input.md
task_count: 7
github: https://github.com/dainn67/wallet-ai/issues/178
---

# Epic: voice-input

## Overview

Add an in-app voice recording affordance to the chat composer that mirrors the
existing image-input pipeline end-to-end: record locally, base64-encode, ship as
a top-level field on `/streaming`, let Gemini interpret the audio natively, and
parse the same `message--//--[records_json]` response. We deliberately reuse
image-input's shape (request field topology, streaming contract, error surface)
so the client adds a thin capture layer + one new request field rather than a
new networking or parsing path. The hardest part is not the wire — it's
(a) picking an audio package that produces a Gemini-supported compressed format
on both iOS and Android without native bloat, and (b) making the recording UI
feel instant (<300 ms) while cleanly handling permission denial, auto-stop at
30 s, and cancel.

## Architecture Decisions

### AD-1: Gemini handles audio natively — no client-side transcription
**Context:** The PRD allows for either shipping raw audio to Gemini or transcribing on-device first. Verified (via Gemini API docs) that standard multimodal models (`gemini-2.0-flash`, `gemini-1.5-*`) accept inline audio parts alongside text in the same `generate_content` call used for images today. Supported formats: WAV, MP3, AIFF, AAC, OGG, FLAC. Limits: 20 MB per request inline, downsampled server-side to 16 kbps mono.
**Decision:** Send raw compressed audio (base64) to the server; the server forwards it as an inline audio part to Gemini. No speech-to-text library on the client.
**Alternatives rejected:**
- Device STT (iOS `SFSpeechRecognizer`, Android `SpeechRecognizer`) → platform-specific, locale caveats, loses prosody the model could use for context ("around nine this morning I paid..."), and the user explicitly does not want keyboard-mic behavior.
- Client-side transcription via a Flutter STT plugin → duplicates what Gemini already does, adds model-dependency, and typically worse Vietnamese accuracy than Gemini.
**Trade-off:** Slightly larger upload payload (≤ ~500 KB for AAC @ 128 kbps × 30 s) vs. a text-only request; in return we get one single multimodal code path and better extraction quality.
**Reversibility:** Easy. Audio is opaque to the client — swapping to a transcribe-first model means replacing "encode + send audio" with "transcribe + send text as query", nothing else changes.

### AD-2: `audio` as a top-level sibling of `query` (mirror image-input's AD-2)
**Context:** The existing image-input feature ships `images` as a top-level sibling of `query`, NOT nested inside `inputs` (the Dify variables map). Omitted entirely when empty. Server team already understands this topology.
**Decision:** Add `audio: string | null` as a top-level field in the request body. Omit the key entirely when no audio is being sent (do not send `null`, do not send empty string). The `query` field is an empty string when audio is sent without a typed caption.
**Alternatives rejected:**
- Nest `audio` inside `inputs.audio` → inconsistent with `images`, forces server to branch on two layouts.
- Separate `/voice` endpoint → doubles streaming plumbing for no routing benefit; server can dispatch on the presence of `audio` just like it does for `images`.
**Trade-off:** One more top-level field. Nothing lost.
**Reversibility:** Trivial (rename or move).

### AD-3: Use `record` package for audio capture
**Context:** Two mature options exist — `record` (thin wrapper, AAC/WAV/Opus, single responsibility) and `flutter_sound` (larger surface, player+recorder, more native weight). We need: start/stop/cancel, duration cap, amplitude stream (for the active-recording indicator), AAC encoding, iOS + Android.
**Decision:** Use `record` (`^5.x`).
**Alternatives rejected:**
- `flutter_sound` → larger native footprint, overkill since we do not play recordings back.
- Platform channels hand-rolled → unnecessary bespoke code.
**Trade-off:** Depend on a third-party package for a core feature. Mitigated by how narrow the use is — if it breaks, swapping is a ~1-day task since the service interface isolates it (see §Technical Approach).
**Reversibility:** Easy — `AudioRecordingService` is a thin facade; swap the implementation.

### AD-4: AAC-LC @ 128 kbps, single `.m4a` container
**Context:** PRD NFR-1 (flagged by validation) had contradictory bitrate values. Gemini supports AAC, MP3, WAV, OGG, FLAC. AAC is natively supported by `record` on both iOS and Android without extra codecs.
**Decision:** Fix the bitrate at **AAC-LC, 128 kbps, mono, 44.1 kHz**. Budget: ~480 KB for 30 s, well under the PRD's 5 MB ceiling and Gemini's 20 MB inline cap. Extension `.m4a`, MIME `audio/aac`.
**Alternatives rejected:**
- OGG/Opus (smaller) → lower reliability on iOS via `record`; AAC already well under budget.
- WAV (simplest) → ~2.6 MB for 30 s mono 16-bit; borderline and wasteful.
**Trade-off:** AAC is slightly lossier than WAV; irrelevant for speech extraction.
**Reversibility:** Change one enum in `AudioRecordingService`.

### AD-5: Detect voice-interpretation failure via empty records array when audio was sent
**Context:** PRD FR-5 wants a specific error message ("I didn't catch that…") distinct from a normal empty-records reply (a non-financial chat). The only client-visible signal is the parsed records array — the SSE format has no error code.
**Decision:** If the outbound request carried `audio` AND the parsed records array is empty (`[]`), replace the assistant's final rendered text with the localized "I didn't catch that. Please try again." string. This decision lives in `ChatProvider._handleStream`.
**Alternatives rejected:**
- Add an error field to the SSE contract → breaks streaming format compatibility and couples client to a new server contract.
- Heuristic keyword match on the assistant's natural reply → brittle across locales.
**Trade-off:** Cannot distinguish "audio understood, user said hello" from "audio not understood" — acceptable because the use case is explicitly expense capture; a voice message that produces no records is a miss from the user's perspective regardless.
**Reversibility:** Easy. Local rule inside `_handleStream`.

### AD-6: Recording UI is a full-width overlay above the composer, not a modal
**Context:** Messenger-style; needs cancel reachable without covering the rest of the screen; must respect the "disabled while streaming" rule from image-input.
**Decision:** When recording starts, the text input is replaced in-place by a recording bar: animated waveform-esque pulse icon, MM:SS elapsed timer, cancel (×) on the left, stop-and-send (■) where the mic was. Single `AnimatedSwitcher` swap in `chat_tab.dart`.
**Alternatives rejected:**
- Modal bottom sheet → heavier, keyboard interactions messier.
- Long-press hold-to-talk → PRD explicitly rejects it.
**Trade-off:** None meaningful.
**Reversibility:** UI-only, easy.

## Technical Approach

### Component 1: `AudioRecordingService` (singleton)
**Why it exists:** Encapsulates `record` package so the rest of the app never imports it directly — lets us swap packages without touching providers or UI.

**New file:** `lib/services/audio_recording_service.dart`

Pattern: follow `ImagePickerService` / `ImageProcessingService` — static `_instance`, private `_internal()`, `factory`, optional `@visibleForTesting setMockInstance`.

Interface:
- `Future<bool> hasPermission()` — delegates to `record.hasPermission()`.
- `Future<bool> requestPermission()` — wraps `permission_handler` if `record`'s own check is insufficient.
- `Future<void> start()` — starts to an app-tmp path, AAC-LC 128 kbps mono.
- `Stream<Duration> get elapsedStream` — 100 ms tick; UI binds to it.
- `Stream<double> get amplitudeStream` — pass-through from `record`; fuels the pulsing indicator.
- `Future<Uint8List?> stop()` — stops, reads bytes, deletes tmp file, returns bytes.
- `Future<void> cancel()` — stops and deletes without returning bytes.
- Hard 30-second timer inside the service — on expiry, auto-calls `stop()` and fires a completion callback the provider listens to.

Export from `lib/services/services.dart`.

### Component 2: Chat composer UI changes
**Why:** Surface the mic icon and the recording state.

**Modified file:** `lib/screens/home/tabs/chat_tab.dart`

- Add `Icons.mic_none_outlined` button next to the existing camera button (same disabled rule as camera: greyed when streaming, same size/padding).
- New private widget `_RecordingBar` swapped in via `AnimatedSwitcher` when `_isRecording`:
  - Left: cancel (×) button.
  - Center: pulsing mic + "0:12" timer driven by `AudioRecordingService.elapsedStream`.
  - Right: stop-and-send (■) button, occupies the send-button slot.
- Permission flow: first tap calls `AudioRecordingService.hasPermission`; if false, show localized rationale dialog, then request. Permanent-deny → snackbar with "Open settings" action (optional — see task T6).

### Component 3: `ChatApiService` — audio field on the wire
**Modified file:** `lib/services/chat_api_service.dart`

- Extend `streamChat(...)` with `String? audioBase64`.
- In the body assembly, after the existing `images` branch:
  ```
  if (audioBase64 != null && audioBase64.isNotEmpty) {
    inputs['audio'] = audioBase64;   // top-level, sibling of `query` and `images`
  }
  ```
  (Note: `inputs` here is the *outer* request map, as in image-input — not the nested Dify variables map.)
- `query` may be an empty string when only audio is sent; the existing path already handles that.

### Component 4: `ChatProvider` — audio plumbing + error surfacing
**Modified file:** `lib/providers/chat_provider.dart`

- `sendMessage(String content, {List<Uint8List>? imageBytes, Uint8List? audioBytes})`.
- In `_handleStream`, base64-encode `audioBytes` just before `streamChat(...)` using `ImageProcessingService().toBase64` (it's byte-agnostic; rename later if we grow a dedicated audio processor, but no conversion is required for MVP).
- Track `_lastSendHadAudio` (or pass through `_handleStream` params).
- In the `onDone` handler: after JSON parsing, if `_lastSendHadAudio && records.isEmpty`, overwrite `assistantMessage.content` with localized "voice_didnt_catch_that" string.
- Guard against rapid re-taps: if `_isStreaming`, the mic button is disabled and `sendMessage(audioBytes: …)` is a no-op (matches image-input rule).

### Component 5: Error strings + image error fix (carried from FR-5)
**Modified files:** `lib/configs/l10n_config.dart` (or wherever localized strings live), English + Vietnamese.

- `voice_didnt_catch_that`: "I didn't catch that. Please try again." / "Mình chưa nghe rõ. Bạn thử lại nhé."
- `image_load_failed`: "Couldn't load the image. Please try again." / "Không tải được ảnh. Bạn thử lại nhé."

Image error surfacing is a small retroactive fix to the already-shipped image-input feature (see Deferred/Follow-up note below) — applied here because the PRD bundles it.

### Component 6: Testing strategy
- **Unit:** `AudioRecordingService` mocked via `setMockInstance`; verify start/stop/cancel/30-s auto-stop; verify bytes returned.
- **Unit:** `ChatApiService` — assert body contains `audio` key only when `audioBase64` is non-empty; assert `query` can be empty when audio present.
- **Unit:** `ChatProvider` — with audio-bearing request and empty-records response, assistant message is replaced with the voice-error string; with non-audio request and empty-records, message is left as-is.
- **Integration:** `tests/integration/epic_voice_input/` — end-to-end with a fake `ChatApiService` returning a canned SSE stream; drive the chat tab through start → stop → send.
- **Manual:** smoke on physical iOS + Android — permission flow, 30-s auto-stop, cancel, audible-silence case.

## Traceability Matrix

| PRD Requirement                           | Epic Coverage                                     | Task(s) | Verification                           |
| ----------------------------------------- | ------------------------------------------------- | ------- | -------------------------------------- |
| FR-1: Mic icon in chat composer           | §Component 2 (chat_tab)                           | T3      | Widget test + manual                   |
| FR-2: Tap-to-record, tap-to-stop + 30s    | §Component 1 (service) + §Component 2 (UI)        | T2, T3  | Unit (service), widget test (UI)       |
| FR-3: Cancel recording                    | §Component 1 (service) + §Component 2 (UI)        | T2, T3  | Unit test + manual                     |
| FR-4: Audio field in request body         | §Component 3 (ChatApiService) + AD-2              | T4      | Unit test asserting body shape         |
| FR-5: Voice + image error messages        | §Component 4 (ChatProvider) + §Component 5 (l10n) | T5, T6  | Unit test (voice path) + manual (img)  |
| NFR-1: Audio ≤5 MB / AAC 128 kbps         | §AD-4                                             | T2      | Service encoder config asserted in test |
| NFR-2: Recording latency <300 ms          | §Component 2 (eager permission check, no modals)  | T3      | Manual timing (stopwatch or DevTools)  |
| NTH-1: Waveform visualization             | Deferred (amplitudeStream reserved)               | —       | —                                      |
| NTH-2: Voice + image in same message      | Deferred                                          | —       | —                                      |

All FR-* and NFR-* requirements map to at least one task. NTH-* deferred (see Deferred/Follow-up).

> **Note on requirement IDs:** PRD already uses FR-1…FR-5, NTH-1…NTH-2, NFR-1…NFR-2 (validated). No re-assignment needed.

## Implementation Strategy

### Phase 1 — Foundation (sequential)
**What:** Pick package, add dependency, wire platform permissions (iOS `NSMicrophoneUsageDescription`, Android `RECORD_AUDIO`), implement `AudioRecordingService` with start/stop/cancel/30s-cap, unit tests.
**Why first:** Every other task depends on this service existing and being trustworthy.
**Exit criterion:** `AudioRecordingService` unit tests pass; can record → get bytes from a sample harness.

### Phase 2 — Core feature (parallelizable after Phase 1)
**What:** Chat composer UI (mic icon + recording bar), `ChatApiService` audio field, `ChatProvider` audio plumbing + error-surface logic, error strings.
**Why parallel:** UI (T3), API (T4), and provider (T5) touch different files; can be built concurrently once T2 produces the `AudioRecordingService` interface.
**Exit criterion:** Can tap mic → speak → tap stop → see a record card back from the real backend (once server routes audio).

### Phase 3 — Polish (sequential after Phase 2)
**What:** Permission edge cases (denied / permanently denied), image error fix (retroactive), integration tests, manual cross-device smoke.
**Why last:** Needs the full flow to exist to verify edge cases meaningfully.
**Exit criterion:** All FR/NFR acceptance criteria pass on iOS + Android; integration test green.

## Task Breakdown

##### T1: Add `record` + `permission_handler` dependencies and platform plumbing
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Add `record: ^5.x` and `permission_handler: ^11.x` to `pubspec.yaml`. Add iOS `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist` (both VN and EN strings). Add `<uses-permission android:name="android.permission.RECORD_AUDIO" />` to `android/app/src/main/AndroidManifest.xml`. Run `fvm flutter pub get`, verify build on both platforms.
- **Key files:** `pubspec.yaml`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`
- **PRD requirements:** FR-1 (prerequisite), FR-2 (prerequisite)
- **Key risk:** iOS privacy manifest may need additional entries for newer SDK; catch during build.
- **Interface produces:** Working mic permission request on both platforms.

##### T2: Implement `AudioRecordingService`
- **Phase:** 1 | **Parallel:** no | **Est:** 1.5d | **Depends:** T1 | **Complexity:** moderate
- **What:** Create `lib/services/audio_recording_service.dart` following the `ImagePickerService` singleton pattern. Expose `hasPermission`, `requestPermission`, `start`, `stop` (returns `Uint8List`), `cancel`, `elapsedStream`, `amplitudeStream`. Encode AAC-LC 128 kbps mono (AD-4). Enforce 30-second hard cap via internal `Timer` that auto-calls `stop`. Write unit tests covering start/stop/cancel/auto-stop. Export from `lib/services/services.dart`.
- **Key files:** `lib/services/audio_recording_service.dart`, `lib/services/services.dart`, `test/services/audio_recording_service_test.dart`
- **PRD requirements:** FR-2, FR-3, NFR-1
- **Key risk:** `record` package's amplitude stream emission rate differs across platforms — UI consumers must be resilient to nulls.
- **Interface produces:** `AudioRecordingService` with the API consumed by T3 and T5.

##### T3: Chat composer mic icon + recording bar UI
- **Phase:** 2 | **Parallel:** yes | **Est:** 1.5d | **Depends:** T2 | **Complexity:** moderate
- **What:** In `lib/screens/home/tabs/chat_tab.dart`, add a mic icon button adjacent to the existing camera button at line ~107 (same disabled rule as camera during `isStreaming`). Add `_isRecording` local state. On tap, check permission → start recording → swap the composer's text field with a `_RecordingBar` via `AnimatedSwitcher`: elapsed-time label bound to `elapsedStream`, animated pulse driven by `amplitudeStream`, × (cancel) on the left, ■ (stop-and-send) on the right. Latency target <300 ms (AD-6, NFR-2). Widget test verifying mic visibility + disabled state + swap to recording bar on tap.
- **Key files:** `lib/screens/home/tabs/chat_tab.dart`, `test/screens/home/tabs/chat_tab_voice_test.dart`
- **PRD requirements:** FR-1, FR-2, FR-3, NFR-2
- **Key risk:** Re-layout jitter when swapping composer↔recording bar; contain inside fixed-height container.
- **Interface receives from T2:** `AudioRecordingService` facade.
- **Interface produces:** Calls `ChatProvider.sendMessage(audioBytes: …)` on stop-and-send.

##### T4: `ChatApiService` — add `audioBase64` parameter + top-level field
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T2 | **Complexity:** simple
- **What:** In `lib/services/chat_api_service.dart`, add `String? audioBase64` to `streamChat(...)` signature. After the existing `if (imagesBase64 != null && imagesBase64.isNotEmpty)` block (line ~83), add the symmetric `audio` branch per AD-2 (top-level, omit key when absent). Update the unit tests in `test/services/chat_api_service_test.dart` to assert: (a) `audio` key absent when param null/empty, (b) `audio` key present + base64 value when param non-empty, (c) `query` may be empty string when audio present.
- **Key files:** `lib/services/chat_api_service.dart`, `test/services/chat_api_service_test.dart`
- **PRD requirements:** FR-4
- **Key risk:** Accidentally placing `audio` inside the nested `inputs` map (Dify variables) instead of the outer request map — exact mistake image-input's AD-2 calls out. Code review checkpoint.
- **Interface receives from T2:** none (pure string param).
- **Interface produces:** `streamChat` accepting audio; consumed by T5.

##### T5: `ChatProvider` — audio plumbing + voice-error surfacing
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T2, T4 | **Complexity:** moderate
- **What:** In `lib/providers/chat_provider.dart`, extend `sendMessage` with `Uint8List? audioBytes`. Thread through `_handleStream` (new optional arg). Just before `streamChat` call at line ~152, base64-encode `audioBytes` via `ImageProcessingService().toBase64`. Track whether the current request carried audio. In `onDone` after JSON parse: if the request had audio AND the parsed records array is empty (`[]`), overwrite the assistant message's content with the localized `voice_didnt_catch_that` string (AD-5). Keep the existing "records non-empty → render record cards" path unchanged. Add unit tests: (a) audio request + empty records → error string shown; (b) audio request + non-empty records → normal path; (c) no-audio request + empty records → message kept as-is.
- **Key files:** `lib/providers/chat_provider.dart`, `test/providers/chat_provider_voice_test.dart`
- **PRD requirements:** FR-4, FR-5 (voice half)
- **Key risk:** State leak between consecutive sends if `_lastSendHadAudio` isn't per-message — prefer threading through `_handleStream` params rather than an instance flag.
- **Interface receives from T4:** `streamChat` accepting `audioBase64`.
- **Interface receives from T2:** `AudioRecordingService` (not strictly needed here; provider only handles bytes).
- **Interface produces:** `sendMessage(audioBytes: …)` consumed by T3.

##### T6: Error strings + image error surfacing (carry from FR-5)
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Add two new localized strings in `lib/configs/l10n_config.dart` (or the project's existing strings file) in English + Vietnamese: `voice_didnt_catch_that`, `image_load_failed`. Wire `image_load_failed` at image-processing error sites (inside `ImageProcessingService`'s try/catch consumers in `ChatProvider` and the chat tab picker flow) as a snackbar — this is a retroactive fix to image-input. Manual verify: force an oversized image → see snackbar, no crash, no empty record card.
- **Key files:** `lib/configs/l10n_config.dart`, `lib/providers/chat_provider.dart`, `lib/screens/home/tabs/chat_tab.dart`
- **PRD requirements:** FR-5 (both halves)
- **Key risk:** Image error paths today may silently swallow — do a quick audit of `try/catch` in the image pipeline before adding UI surface.
- **Interface produces:** localized keys consumed by T5 (voice) and T3/chat-tab (image snackbar).

##### T7: Integration tests + cross-device smoke
- **Phase:** 3 | **Parallel:** no | **Est:** 1d | **Depends:** T3, T5, T6 | **Complexity:** moderate
- **What:** Create `tests/integration/epic_voice_input/` with a mocked `ChatApiService` returning canned SSE. Scenarios: happy path (record → stop → record appears), cancel (no message sent), 30-s auto-stop (timer fires, audio sent), voice not understood (empty records → error string), streaming-in-progress (mic disabled), permission denied (rationale → snackbar). Then manual smoke on one physical iOS + one physical Android: permission first-prompt, mic latency feel, elapsed timer accuracy, background interruption (incoming call). Document findings in `docs/features/voice-input.md`.
- **Key files:** `tests/integration/epic_voice_input/voice_input_test.dart`, `docs/features/voice-input.md`
- **PRD requirements:** FR-1, FR-2, FR-3, FR-5, NFR-2
- **Key risk:** Background interruption (phone call, Siri) may leave the recorder in a bad state; verify `record` handles audio-session loss or add a `WidgetsBindingObserver` for `AppLifecycleState.paused`.
- **Interface receives from T3, T5, T6:** full end-to-end flow.

## Risks & Mitigations

| Risk                                                                           | Severity | Likelihood | Impact                                              | Mitigation                                                                                                                             |
| ------------------------------------------------------------------------------ | -------- | ---------- | --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `record` package produces incompatible format on one platform                  | High     | Low        | Feature ships broken on iOS or Android              | AD-4 pins AAC-LC; verify format on both physical devices in T2 before moving on                                                       |
| Base64 audio payload pushes past backend body-size limits                      | Medium   | Low        | 500-level errors; user sees generic failure          | AD-4 budgets ≤480 KB for 30 s (vs. PRD 5 MB cap and Gemini 20 MB); validate once against the real `/streaming` endpoint post-T4        |
| Mic permission UX confuses users who deny on first prompt                      | Medium   | Medium     | Users think the mic is broken                      | Rationale dialog before the system prompt (T3); on permanent-deny show snackbar with "Open settings" action; mic icon stays tappable   |
| Voice error detection (empty `[]` records) fires on legitimate non-expense chat | Medium   | Low        | False "didn't catch that" on normal voice chat      | AD-5 scopes the rule to audio-bearing requests only; purpose of voice input per PRD is expense capture — acceptable trade-off          |
| AudioSession loss (incoming call, Siri) during recording                       | Medium   | Medium     | Recording bar stuck; audio truncated or empty       | T7 covers `AppLifecycleState.paused` handling: auto-cancel recording on interruption, restore composer                                |
| Server doesn't ship audio routing before client releases                        | High     | Medium     | Client sends audio; server ignores → always error   | Feature-flag the mic icon (off by default) until server-update-voice-input.md is landed; coordinate via `server-team` dependency below |
| Accessibility: mic button has no label, blind users stuck                      | Low      | Medium     | Fails WCAG basics                                   | Add `Semantics(label: 'Record voice message')` in T3                                                                                   |

## Dependencies

- **Gemini audio input (already supported)** — Owner: Google — Status: resolved (verified). No action needed; standard `generate_content` accepts audio inline.
- **Server `/streaming` adds `audio` field routing** — Owner: server team — Status: pending (`docs/server-update-voice-input.md` handed off). Client can ship the field ahead of server; voice messages will round-trip as empty-records until server lands, which triggers the "didn't catch that" error — acceptable behind a feature flag.
- **`record` Flutter package** — Owner: third-party (llfbandit) — Status: resolved (stable v5). T1 adds the dep.
- **`permission_handler`** — Owner: third-party (Baseflow) — Status: resolved. T1 adds the dep.
- **Retroactive image-input error-surface fix (T6)** — Owner: client team (this epic) — Status: pending in this epic. Bundles a small fix into FR-5.

## Success Criteria (Technical)

| PRD Criterion                                                  | Technical Metric                                                | Target    | How to Measure                                             |
| -------------------------------------------------------------- | --------------------------------------------------------------- | --------- | ---------------------------------------------------------- |
| Feature adoption (≥20% of WAU use voice in first week)         | `voice_send` analytics event count / WAU                        | ≥ 20%     | Analytics dashboard — fire event on first successful send  |
| Successful extraction rate (≥70% of voice sends return ≥1 record) | Client-side: % of voice sends where `records.length > 0`      | ≥ 70%     | Aggregated client log / server log of voice-bearing requests |
| Error rate (≤20% show "didn't catch that")                     | Client: voice-error-string impressions / voice sends             | ≤ 20%     | Client analytics — fire event in AD-5 error branch          |
| Recording latency (NFR-2)                                      | ms between mic-tap and recording-bar-visible                     | < 300 ms  | Manual DevTools timeline + visual stopwatch on real device  |
| Audio payload size (NFR-1)                                     | Bytes of base64-encoded 30 s recording                           | ≤ 5 MB    | Unit-test asserts `stop()` output ≤ ~500 KB raw (~700 KB b64) |

## Estimated Effort

- **Total:** ~6 dev-days for one developer.
- **Critical path:** T1 → T2 → (T3 ∥ T4 ∥ T5 ∥ T6) → T7 ≈ 0.5 + 1.5 + 1.5 (longest parallel arm) + 1 = **4.5 days wall-clock** with one dev; ~3.5 days with two.
- **Phases:** Phase 1 ~2d, Phase 2 ~1.5d wall-clock (parallel), Phase 3 ~1d.

## Deferred / Follow-up

- **NTH-1: Live waveform visualization** — `AudioRecordingService.amplitudeStream` is exposed in T2 so a follow-up can render it; for MVP a pulsing mic icon is sufficient.
- **NTH-2: Voice + image in the same message** — server contract would need to accept both simultaneously; deferred to a future epic once voice-only is in production.
- **Empty-recording guard (validation recommendation 3)** — if the user taps start then stop within ~1 second, show "Recording too short." Not in this epic; add if usage shows false sends.
- **Settings deep-link for permanently-denied permission** — T6 uses a snackbar; a proper settings deep-link can follow in a polish pass.
- **Hands-occupied / Multi-item-logger persona stories** — PRD validation noted these personas lack dedicated stories; their needs are covered by the MVP flow, but dedicated UX affordances (e.g. voice confirmation) can be a follow-up.

## Tasks Created

| #   | Task                                                    | Phase | Parallel | Est.  | Depends On      | Status |
| --- | ------------------------------------------------------- | ----- | -------- | ----- | --------------- | ------ |
| 001 | Add record + permission_handler deps + platform plumbing | 1     | no       | 0.5d  | —               | open   |
| 002 | Implement AudioRecordingService singleton               | 1     | no       | 1.5d  | 001             | open   |
| 010 | Chat composer mic icon + recording bar UI               | 2     | yes      | 1.5d  | 002             | open   |
| 011 | ChatApiService — add audioBase64 + top-level audio field | 2     | yes      | 0.5d  | 002             | open   |
| 012 | ChatProvider — audio plumbing + voice-error surfacing   | 2     | yes      | 1d    | 002, 011        | open   |
| 013 | Error strings — voice and image failure messages        | 2     | yes      | 0.5d  | —               | open   |
| 090 | Integration tests, cross-device smoke, and docs         | 3     | no       | 1d    | 001,002,010,011,012,013 | open |

### Summary
- **Total tasks:** 7
- **Parallel tasks:** 4 (Phase 2: 010, 011, 012, 013)
- **Sequential tasks:** 3 (Phase 1: 001, 002 — Phase 3: 090)
- **Estimated total effort:** ~6.5d
- **Critical path:** 001 → 002 → 010 → 090 (~4.5d)

### Dependency Graph
```
001 ──→ 002 ──→ 010 (parallel) ──→ 090
              ──→ 011 (parallel) ──→ 090
              ──→ 012 (parallel) ──→ 090
013 (parallel, no deps) ─────────→ 090

Critical path: 001 → 002 → 010 → 090 (~4.5d wall-clock)
```

### PRD Coverage
| PRD Requirement | Covered By   | Status     |
| --------------- | ------------ | ---------- |
| FR-1: Mic icon  | 010, 090     | ✅ Covered |
| FR-2: Tap-to-record/stop + 30s | 002, 010, 090 | ✅ Covered |
| FR-3: Cancel    | 002, 010, 090 | ✅ Covered |
| FR-4: Audio field in request | 011, 012 | ✅ Covered |
| FR-5: Voice + image error messages | 012, 013, 090 | ✅ Covered |
| NFR-1: Audio ≤5 MB / AAC 128 kbps | 002         | ✅ Covered |
| NFR-2: Recording latency <300 ms | 010, 090    | ✅ Covered |
| NTH-1: Waveform visualization | Deferred      | — Deferred |
| NTH-2: Voice + image combined | Deferred      | — Deferred |
