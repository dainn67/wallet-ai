---
name: image-input
description: Attach photos (receipts, bill/bank screenshots) to chat messages for AI record extraction, reusing the existing /streaming endpoint.
status: backlog
priority: P1
scale: medium
created: 2026-04-21T16:30:26Z
updated: null
---

# PRD: image-input

## Executive Summary

Wally AI today only accepts text in the chat tab, so users who want to log a purchase from a paper receipt or a bank-notification screenshot must retype every number — slow, error-prone, and a common drop-off point for daily logging. This PRD adds an image attachment control inside the existing chat input: users tap a camera/gallery icon, pick up to five photos (with lazy permission prompts), and send them alongside an optional caption. The client compresses images and posts them as a new `images` field on the existing `/streaming` endpoint; the server detects the field, runs its vision pipeline, and streams back the same record-array JSON the text flow already produces. Shipping this removes the biggest friction in day-to-day entry while keeping the client simple — no OCR logic on device, no new response parsing, no new endpoints.

## Problem Statement

**Who is affected:** Anyone logging real-world spending in Wally — i.e., the whole active user base. The pain is sharpest for users who transact physically (paper receipts from restaurants, groceries, parking) and users on apps/banks that notify by push or SMS screenshots rather than structured APIs.

**Frequency & severity:** Daily for engaged users (typically 3-10 transactions per day end up with a receipt or notification). Severity is "annoying but blocking-adjacent" — not a crash, but the friction is high enough that users skip logging entries entirely rather than type them, which directly undermines Wally's value proposition of a complete financial picture.

**Cost of inaction:** Each skipped receipt is a gap in the user's data, which cascades into bad category totals, bad AI pattern analysis, and worse adaptive greetings. Competing financial assistants (including generic chat tools users already trust — ChatGPT, Gemini, Claude) all accept images; Wally feels dated without this.

**Workarounds today:**
- Manually reading the receipt and typing "coffee 45k" into chat (slow, error-prone).
- Skipping the log entirely and hoping memory fills the gap later (data loss).
- Taking photos but never logging them; screenshots pile up in the camera roll (data loss).

None of these preserve the fidelity of the original document. Users have asked for this behavior explicitly and observe it as standard in every chat-based AI product they use.

## Target Users

- **Everyday Logger** — *Context:* Snaps a receipt right after paying at a café, store, or restaurant. *Primary need:* One-tap capture that produces an accurate record without typing. *Pain level:* High — this is the core daily flow today.
- **Screenshot Forwarder** — *Context:* Bank/e-wallet (Momo, ZaloPay, bank push notifications) issues a payment notification; user screenshots it and wants to log it. *Primary need:* Drop the screenshot into chat and let AI pull out amount + counterparty + time. *Pain level:* High — currently requires retyping digits from a screenshot they can't copy-paste.
- **Mixed-Context User** — *Context:* Wants to send a photo *and* add context (e.g., "*split this with Alice*", "*this was last Friday*"). *Primary need:* Image + caption text in a single message, the same mental model they have from ChatGPT / Gemini / Claude. *Pain level:* Medium — workable without it, but feels broken if the two paths are mutually exclusive.

## User Stories

**US-1: Quick receipt capture**
As an Everyday Logger, I want to tap a camera icon in the chat input, snap a receipt, and send it, so that I can log the transaction without typing anything.

Acceptance Criteria:
- [ ] A camera/gallery icon is visible at the end of the chat text field at all times.
- [ ] Tapping it presents camera + gallery options in one sheet.
- [ ] First tap on either option triggers the native OS permission prompt (permissions are NOT requested at app launch).
- [ ] After capture, a thumbnail appears above the text field; send remains enabled.
- [ ] Sending produces records visible in the Records tab within the same response streaming cycle as the text flow.

**US-2: Screenshot a notification, log the transaction**
As a Screenshot Forwarder, I want to attach a bank-notification screenshot to a chat message, so that I don't have to retype numbers from an image I can't copy.

Acceptance Criteria:
- [ ] A screenshot picked from the gallery uploads and produces a record with correct amount and a reasonable category guess.
- [ ] If the server cannot extract a record, an error bubble appears in chat (same style as current text-flow errors) and no record is created.

**US-3: Caption alongside image**
As a Mixed-Context User, I want to attach one or more images and type a caption in the same message, so that I can add context the image doesn't contain (date hints, splits, notes).

Acceptance Criteria:
- [ ] An image + text message sends as a single streaming request that carries both.
- [ ] The outgoing user bubble shows both the image thumbnails and the caption text.
- [ ] The AI response treats the caption as additional context for extraction (server contract — validated by observing expected records).

**US-4: Multiple images in one message**
As an Everyday Logger, I want to attach up to 5 images at once, so that I can log a whole café-run or multi-receipt batch in one send.

Acceptance Criteria:
- [ ] The gallery picker supports multi-select up to 5 images.
- [ ] Helper text near the attachment row reads "Up to 5 images".
- [ ] If the user tries to add a 6th, the UI blocks it with a clear inline hint.
- [ ] Each picked image has an "x" affordance to remove it before send.

## Requirements

### Functional Requirements (MUST)

**FR-1: Attachment entry point in chat input**
Add a camera/gallery icon inside the chat text field, at the trailing edge, visible whenever the input is visible. Tapping it opens a native action sheet offering "Take photo" and "Choose from library".

Scenario: Happy path — entry point visible
- GIVEN the user is on the ChatTab
- WHEN the chat input is rendered
- THEN an image/camera icon is present at the trailing end of the text field
- AND tapping it opens an action sheet with "Take photo" and "Choose from library" options.

Scenario: Icon remains available during typing
- GIVEN the user has typed text but not sent
- WHEN the user looks at the input
- THEN the attachment icon is still visible and tappable.

**FR-2: Lazy permission request**
Camera and photo-library permissions are requested only on first tap of the respective option, not at app launch. Standard OS prompts are used (no custom pre-prompt).

Scenario: First-time tap — permission prompt
- GIVEN the user has never granted camera permission to Wally
- WHEN the user taps "Take photo" for the first time
- THEN the OS camera permission prompt appears before the camera opens.

Scenario: Denied permission — graceful path
- GIVEN the user has denied photo-library permission
- WHEN the user taps "Choose from library"
- THEN an inline message explains the denial and offers a link to OS settings
- AND the app does not crash or retry the prompt automatically.

Scenario: App launch does not prompt
- GIVEN a freshly installed app
- WHEN the user opens Wally and lands on the ChatTab
- THEN no camera or photo-library permission prompt appears until the attachment flow is invoked.

**FR-3: Multi-image selection with 5-image cap**
Users can attach up to 5 images per message. The gallery picker supports multi-select. Exceeding 5 is blocked in UI with a visible helper note.

Scenario: Happy path — pick 3 images
- GIVEN the user taps "Choose from library"
- WHEN they select 3 images and confirm
- THEN 3 thumbnails appear above the text field
- AND the send button is enabled.

Scenario: Edge — attempt to pick 6
- GIVEN the user has 4 images already attached
- WHEN they try to add 2 more via the picker
- THEN only 1 additional image is accepted (total 5)
- AND a clear inline message states "Up to 5 images".

Scenario: Remove an attached image
- GIVEN the user has 3 images attached but not yet sent
- WHEN they tap the "x" on the second thumbnail
- THEN that thumbnail is removed and the count drops to 2.

**FR-4: Client-side compression pipeline**
Before upload, each image is decoded, auto-rotated via EXIF, resized so its longest edge is ≤1600px, and re-encoded as JPEG quality 85. HEIC input (common on iOS) is decoded natively and output as JPEG. Images already smaller than the thresholds pass through without re-encoding. Post-compression, any single image exceeding 1.5 MB is rejected with an inline error.

Scenario: Happy path — large photo compressed
- GIVEN the user picks a 4000×3000 px, 4 MB JPEG
- WHEN the send button is tapped
- THEN the image is resized to max 1600px on its longest edge
- AND re-encoded as JPEG quality 85
- AND the resulting file is below 1.5 MB.

Scenario: HEIC input on iOS
- GIVEN the user picks a HEIC image from an iPhone gallery
- WHEN the compression pipeline runs
- THEN the image is decoded and re-encoded as JPEG
- AND the upload payload contains a JPEG base64 string (not HEIC).

Scenario: Small image — pass through
- GIVEN the user picks a 800×600 px, 120 KB JPEG
- WHEN compression runs
- THEN the image is not re-encoded (or is re-encoded losslessly enough to produce a similar size)
- AND upload proceeds normally.

Scenario: Edge — image still too large after compression
- GIVEN a pathological image remains >1.5 MB after compression
- WHEN send is invoked
- THEN that specific image is rejected with an inline message
- AND other valid images in the same message still send.

**FR-5: Upload via existing `/streaming` endpoint with new `images` field**
The client reuses `ChatApiService.sendStreamingMessage` to post to the existing `/streaming` endpoint. Images are attached as base64-encoded JPEG strings in a new top-level JSON field named `images` (array). The existing user-message text field and all other payload fields remain unchanged. The server detects the presence of `images` to branch into vision extraction and returns the same record-array JSON the text flow produces. The existing `ChatProvider._handleStream` parser consumes the response unchanged.

Scenario: Happy path — images + caption send
- GIVEN 2 compressed images and the caption text "lunch with Alice"
- WHEN the user taps send
- THEN the POST body includes `query: "lunch with Alice"` AND `images: [<base64>, <base64>]`
- AND the request targets the same `/streaming` path as text-only messages.

Scenario: Images-only message (no caption)
- GIVEN 1 image attached and an empty caption field
- WHEN the user taps send
- THEN the POST body still includes `images: [<base64>]`
- AND the `query` field is sent as empty string (or omitted per existing text-flow convention).

Scenario: Response stream parsed by existing pipeline
- GIVEN the server returns its normal record-array JSON after the `--//--` delimiter
- WHEN the stream completes
- THEN `ChatProvider._handleStream`'s onDone parses records identically to the text flow
- AND records land in SQLite via `RecordRepository` with no new code path.

**FR-6: Outgoing-message bubble renders thumbnails + caption**
The user's own chat bubble renders the attached image thumbnails (tap to view full-size) alongside the caption text. Visual style follows existing ChatBubble patterns.

Scenario: Happy path — bubble layout
- GIVEN the user has sent 2 images with the caption "breakfast"
- WHEN the outgoing bubble renders
- THEN both image thumbnails are visible in the bubble
- AND the caption "breakfast" is visible below or adjacent to them.

Scenario: Tap to view
- GIVEN a sent bubble containing images
- WHEN the user taps a thumbnail
- THEN a full-size viewer opens (at minimum a simple fullscreen preview).

**FR-7: Error handling reuses existing chat error bubble**
Upload failures, server errors, and extraction failures (server returns an error or an empty record array with an error payload) all surface through the existing chat error bubble pattern used by the text flow. No new error UI is introduced.

Scenario: Upload times out
- GIVEN the network request fails after the client timeout
- WHEN the stream handler processes the failure
- THEN an error bubble appears in the chat stream identical in style to a failed text message
- AND no records are persisted.

Scenario: Server returns an extraction error
- GIVEN the server responds with an error (e.g., couldn't read images)
- WHEN the response is parsed
- THEN the user sees an error bubble with the server's message (or a generic fallback)
- AND no records are persisted.

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: "Take photo" full-bleed camera preview**
Instead of the OS camera hand-off, launch an in-app camera with auto-capture assistance for receipts (edge detection, perspective). *Deferred — high implementation cost; native camera flow is sufficient for v1.*

Scenario: Happy path
- GIVEN the user taps "Take photo"
- WHEN an in-app camera opens
- THEN live edge-detection highlights a receipt in frame.

**NTH-2: Retry-failed-upload affordance**
Add a "Retry" button on the error bubble to re-attempt the exact same request (images still in memory) without re-picking. *Deferred — re-picking works; retry adds state management complexity best handled after we observe real failure rates.*

Scenario: Happy path
- GIVEN an upload failed and the error bubble shows Retry
- WHEN the user taps Retry
- THEN the same compressed images are re-uploaded without re-selection.

### Non-Functional Requirements

**NFR-1: Upload size budget**
Total compressed payload (5 images worst case) stays under **8 MB raw / ~10.7 MB base64** per request. Typical payloads for bills/screenshots are expected to land ~2-4 MB base64.

**NFR-2: Compression performance**
Compressing 5 images in parallel completes in **≤2.5 seconds on a mid-range device** (e.g., Pixel 6a / iPhone 12). Compression uses native `flutter_image_compress` (not pure-Dart).

**NFR-3: Cross-platform parity**
Behavior, UI, permission flows, and compression output are functionally identical on iOS 14+ and Android 10+ (Flutter SDK `^3.9.2` target). HEIC decoding works natively on both.

**NFR-4: Permission prompt timing**
No camera or photo-library permission is requested until the user explicitly taps the camera or gallery option for the first time. Verified by cold-launching the app and confirming no prompt appears until an attachment action is taken.

## Success Criteria

- **Adoption:** Within 4 weeks of release, **≥25% of active chat users** send at least one image-bearing message. Measured via server-side count of `/streaming` requests carrying a non-empty `images` field / DAU.
- **Extraction reliability:** **≥85% of image-bearing messages** produce at least one record (non-empty response record array, non-error). Measured via server logs comparing `images`-carrying requests to resulting record persistence events.
- **Upload success rate:** **≥97% of image uploads complete without client-side error** (timeout, compression failure, oversize rejection) on the happy path. Measured via a client-logged counter for attempts vs. successes, sampled over rolling 7 days.
- **Permission timing compliance:** **0 permission prompts** observed on cold app launch in manual QA across iOS + Android. Verified by scripted QA run before release.
- **Compression effectiveness:** Median post-compression image size ≤800 KB; 95th percentile ≤1.5 MB. Measured via client-logged pre/post sizes during beta.

## Risks & Mitigations

| Risk                                                                                             | Severity | Likelihood | Mitigation                                                                                                                                                                                   |
| ------------------------------------------------------------------------------------------------ | -------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Slow networks time out on 5-image uploads, frustrating users                                     | High     | Medium     | Aggressive client-side compression (1600px / Q85), hard per-image cap at 1.5 MB post-compression. Explicit error bubble on timeout, no silent drop. Consider client timeout bump (post-launch). |
| Server vision pipeline returns unreliable extractions for noisy photos, hurting extraction-rate KPI | High     | Medium     | Server-team ownership of extraction quality; this PRD treats server as a dumb contract. Client never claims "success" until records actually stream back. Track NFR metric to detect regression early. |
| Android 13+ photo-picker / iOS Photos permission changes break the picker flow                   | Medium   | Low        | Use maintained `image_picker` (handles platform differences). Manually verify on iOS 14/17 and Android 10/13/14 before release.                                                             |
| HEIC decoding fails on certain iPhone models, producing empty or corrupt JPEGs                   | Medium   | Low        | Use `flutter_image_compress` (native HEIC decode). Add a fallback that rejects undecodable images with a clear inline error rather than uploading garbage.                                   |
| Large base64 payloads blow up memory on low-end Android devices during encoding                  | Medium   | Low        | Compress before base64; run encoding on an isolate / compute() if profiling shows jank. 5 × 1.5 MB worst-case is ~10 MB base64 string — acceptable but worth confirming on a 2 GB RAM device. |

## Constraints & Assumptions

**Constraints:**
- Must reuse the existing `/streaming` endpoint — no new endpoint, no new auth, no new base URL (per user direction).
- Must not add a new response-parsing code path — server contract mirrors the text flow.
- Must not request permissions at app launch (per user direction and privacy posture).
- Must work on both iOS and Android with the current Flutter SDK (`^3.9.2`).
- The only font is Poppins (local asset); any new UI must respect this.

**Assumptions:**
- *The server will ship vision-extraction support on the same `/streaming` endpoint before or alongside the client release.* **If wrong:** Client ships with a dead feature that produces only error bubbles. Mitigate by coordinating server readiness before enabling the UI (feature flag if needed).
- *`images` is an acceptable field name and base64 JPEG is an acceptable wire format for the server team.* **If wrong:** Small naming/encoding change on both sides before ship — cheap to correct if caught during server spec review.
- *Typical user photos are bills and screenshots ≤4 MB pre-compression.* **If wrong:** The 1.5 MB post-compression cap may trigger more than expected; we'd need to raise it or add a progress indicator.
- *`flutter_image_compress` remains a maintained, working package.* **If wrong:** Fall back to `image` package (pure Dart, slower but always works).

## Out of Scope

- **Offline OCR / on-device extraction** — the whole pipeline is server-side; any "works offline" capability is a separate project.
- **Image cropping or editing before upload** — users send what they pick. Rotation is automatic via EXIF; nothing else.
- **PDF or document-scanner mode** — attachment is limited to single-frame images.
- **Saving picked/captured images to the user's device** — we never persist to the camera roll on the user's behalf.
- **Batch upload of >5 images per message** — hard cap at 5 to keep payloads sane.
- **Retry-queue for failed uploads** — failed messages do not auto-retry; user re-picks (NTH-2 tracks the retry affordance as a future nice-to-have).
- **In-app camera with edge/receipt detection** — NTH-1; v1 uses the OS camera hand-off.
- **New chat error UI** — we reuse the existing error bubble pattern; no new error surfaces.
- **Rich preview before send (zoom, reorder)** — thumbnails + remove-x only; reorder is not supported.

## Dependencies

- **Server `/streaming` vision support** — server team — *Status: pending.* Server must detect the `images` field and branch to the vision pipeline returning the existing record-array response shape. Required before client release.
- **`image_picker` Flutter plugin** — external (maintained) — *Status: pending install.* For camera + gallery picking, multi-select, and platform-permission integration.
- **`flutter_image_compress` Flutter plugin** — external (maintained) — *Status: pending install.* For native HEIC decode, EXIF auto-orient, resize, and JPEG re-encode.
- **`ChatApiService.sendStreamingMessage`** — internal (existing) — *Status: resolved.* Payload construction function to extend with an optional `images` parameter.
- **`ChatProvider._handleStream`** — internal (existing) — *Status: resolved.* Response parser reused unchanged; no modification planned.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-7]
  nice_to_have: [NTH-1, NTH-2]
  nfr: [NFR-1, NFR-2, NFR-3, NFR-4]
scale: medium
discovery_mode: full
validation_status: warning
last_validated: 2026-04-21T16:35:02Z
