---
name: voice-input
description: Let users record a voice message in the chat composer and send it to the AI to extract financial records.
status: backlog
priority: P1
scale: medium
created: 2026-04-22T11:35:25Z
updated: null
---

# PRD: voice-input

## Executive Summary

WalletAI users currently can only log expenses by typing or attaching an image. This feature adds a mic icon to the chat composer that lets users record a short voice message (up to 30 seconds), which is sent directly to the AI model to listen to and extract financial records — no client-side transcription involved. The response format is unchanged, so no client parser changes are needed. The feature reduces friction for on-the-go recording, complementing the existing image-input feature.

## Problem Statement

Typing an expense while hands are busy — finishing a meal, carrying bags, driving — creates enough friction that users skip recording altogether and lose the data. The device keyboard's built-in microphone button is a workaround, but it produces transcribed text that still requires the user to review and send manually. There is no seamless, in-app way to speak an expense and have it recorded.

## Target Users

- **On-the-go recorder** — Records expenses immediately after they happen (at the register, leaving a restaurant). Needs the fastest possible input method. Pain level: high — often skips recording because typing is too slow.
- **Hands-occupied user** — Cooking, carrying, doing something physical while wanting to log an expense. Can't type at all. Pain level: high — currently has no usable option.
- **Multi-item logger** — Wants to describe several items verbally at once ("lunch 50k, coffee 25k, parking 10k"). Finds typing multiple records tedious. Pain level: medium.

## User Stories

**US-1: Record and send a voice message**
As an on-the-go recorder, I want to tap a mic icon, speak my expense, tap again to stop, and have it sent to the AI, so that I can log a record without typing.

Acceptance Criteria:
- [ ] A mic icon is visible next to the camera icon in the chat input area.
- [ ] Tapping the mic starts recording; the UI clearly indicates recording is active (e.g., animated indicator, elapsed time).
- [ ] Tapping again stops recording and sends the voice message immediately.
- [ ] Recording is capped at 30 seconds; it stops and sends automatically when the limit is reached.
- [ ] The AI responds with the standard `message--//--[records_json]` format, which the app parses as normal.

**US-2: Cancel an accidental recording**
As any user, I want to cancel a recording I started by mistake, so that nothing is sent.

Acceptance Criteria:
- [ ] While recording, there is a visible cancel action (e.g., swipe or a cancel button).
- [ ] Cancelling discards the audio and returns to the normal composer state with no message sent.

**US-3: Understand when voice fails**
As any user, when the AI cannot interpret my voice message, I want a clear error message, so that I know to try again.

Acceptance Criteria:
- [ ] If the AI returns no parseable records and indicates it couldn't understand the audio, the app shows: "I didn't catch that. Please try again."
- [ ] The chat does not show a broken or empty record card.

**US-4: Understand when an image fails to load**
As any user, when an attached image cannot be processed, I want a clear error message, so that I know to retry.

Acceptance Criteria:
- [ ] If image processing fails (upload error, oversize after compression, decode failure), the app shows: "Couldn't load the image. Please try again."
- [ ] No silent failure — the error is always surfaced to the user.

## Requirements

### Functional Requirements (MUST)

**FR-1: Mic icon in chat composer**
A mic icon is added to the chat input area, positioned next to the existing camera icon. It is disabled while a message is streaming (same rule as the camera icon).

Scenario: Normal state
- GIVEN the user is on the chat screen and no message is streaming
- WHEN they look at the input area
- THEN a mic icon is visible next to the camera icon

Scenario: Disabled during streaming
- GIVEN the AI is currently streaming a response
- WHEN the user looks at the mic icon
- THEN the mic icon is disabled/greyed out

**FR-2: Tap-to-record, tap-to-stop interaction**
Tapping the mic icon starts recording. Tapping it again stops recording and triggers sending. No press-and-hold.

Scenario: Happy path
- GIVEN the user taps the mic icon
- WHEN recording starts
- THEN the UI enters "recording mode" with a visible animated indicator and an elapsed time counter
- AND tapping the mic again stops recording and sends the audio

Scenario: 30-second auto-stop
- GIVEN the user is recording
- WHEN 30 seconds elapse
- THEN recording stops automatically and the audio is sent without requiring a second tap

**FR-3: Cancel recording**
The user can cancel an in-progress recording before sending.

Scenario: Cancel
- GIVEN the user is in recording mode
- WHEN they tap the cancel action
- THEN the recording is discarded, no audio is sent, and the composer returns to its default state

**FR-4: Audio sent as a new field in the existing request body**
The recorded audio is encoded (base64 or equivalent) and sent to the `/streaming` endpoint as a new field alongside the existing `query`, `inputs`, etc. The `query` field may be empty when only audio is sent.

Scenario: Voice-only message
- GIVEN the user records audio and sends without typing
- WHEN the request is built
- THEN the request body contains the encoded audio in the new field and `query` is an empty string

Scenario: Voice + text
- GIVEN the user types text and records audio
- THEN both are sent; the text goes in `query`, the audio in the new field

**FR-5: Error feedback for voice and image failures**
- Voice failure (AI could not interpret): show "I didn't catch that. Please try again."
- Image failure (processing error, oversize, decode failure): show "Couldn't load the image. Please try again."

Scenario: Voice failure
- GIVEN the AI cannot interpret the audio
- WHEN the stream completes
- THEN the app displays the voice error message in the chat

Scenario: Image failure
- GIVEN image processing throws an error at any stage
- WHEN the error is caught
- THEN the app displays the image error message (snackbar or inline)

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Waveform visualization during recording**
Show a live audio waveform while recording to give the user confidence the mic is picking up sound. Deferred because the animated indicator in FR-2 is sufficient for MVP.

**NTH-2: Voice + image in the same message**
Allow attaching both audio and images in one send. Deferred — server routing for combined multimodal input adds complexity; ship voice-only first.

### Non-Functional Requirements

**NFR-1: Audio file size**
The client must compress or limit audio bitrate so the encoded audio sent in the request body does not exceed 5 MB for a 30-second recording. Target: ≤ 1 Mbps bitrate (e.g., AAC 128 kbps).

**NFR-2: Recording latency**
Recording must start (mic active, UI updates) within 300 ms of the user tapping the mic icon.

## Success Criteria

| Criterion | Metric | Target | How to Measure |
|-----------|--------|--------|----------------|
| Feature adoption | % of active users who use voice at least once in first week | ≥ 20% | Analytics event on first voice send |
| Successful extraction rate | % of voice messages that return ≥ 1 parseable record | ≥ 70% | Server-side log of voice requests vs. parsed records |
| Error rate | % of voice sends that show the "didn't catch that" error | ≤ 20% | Client error event count / total voice sends |

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Audio file too large for API | High | Medium | Enforce bitrate cap client-side before encoding; reject and show error if still over limit |
| Gemini audio support limited to specific formats/duration | High | Medium | Verify supported formats (e.g., AAC, FLAC, WAV, OGG) and duration limits in Gemini docs before implementation; align client encoding to supported format |
| Microphone permission denied by user | Medium | Medium | Show a clear permission rationale dialog before requesting; gracefully disable the mic icon if denied |
| Poor extraction quality on noisy audio | Medium | High | Set AI prompt expectations accordingly; rely on the "didn't catch that" error path for unrecoverable cases |

## Constraints & Assumptions

**Constraints:**
- Max recording duration: 30 seconds (hard cap, auto-stops).
- Voice and image cannot be combined in the same message in this iteration.
- Server implementation of the voice flow is out of scope for the client epic — client ships the field; server routes it later.

**Assumptions:**
- Gemini (the current LLM provider) supports audio input natively. If wrong, a client-side transcription step must be added before sending.
- The Flutter `record` or `flutter_sound` package (or equivalent) can produce a compressed audio format Gemini accepts. If wrong, audio format conversion must be added.
- The existing `/streaming` endpoint can accept a larger payload for audio. If wrong, a separate audio upload endpoint may be needed.

## Out of Scope

- Device system speech-to-text (keyboard mic replacement) — the feature is in-app recording only.
- Playback of the AI's text response as audio — text-only response is sufficient.
- Voice + image combined in one message — deferred to a follow-up.
- Speaker identification or multi-speaker support — single user recording only.
- Server-side voice flow implementation — documented separately in `docs/server-update-voice-input.md`.

## Dependencies

- Gemini audio input API support — must verify accepted formats and size limits before client implementation.
- Flutter audio recording package (e.g., `record`, `flutter_sound`) — package selection needed; must support iOS + Android with compression.
- `docs/server-update-voice-input.md` — server team needs requirements doc to implement routing and prompt.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5]
  nice_to_have: [NTH-1, NTH-2]
  nfr: [NFR-1, NFR-2]
scale: medium
discovery_mode: express
validation_status: warning
last_validated: 2026-04-22T11:38:05Z
