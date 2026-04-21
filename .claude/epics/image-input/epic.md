---
name: image-input
status: backlog
created: 2026-04-21T16:38:38Z
progress: 0%
priority: P1
prd: .claude/prds/image-input.md
task_count: 7
github: "https://github.com/dainn67/wallet-ai/issues/169"
updated: 2026-04-21T16:43:17Z
---

# Epic: image-input

## Overview

We extend the existing chat input and streaming pipeline to carry images alongside text. The client is a dumb pipe: pick images, compress natively, base64-encode, add to the outbound `/streaming` body as a new field, and reuse the existing `ChatProvider._handleStream` parser unchanged. No new endpoint, no new response shape, no new error UI. The most architecturally sensitive choice is *when* compression runs (on pick, not on send) and *where* the new payload field lives (top-level sibling of `query`, confirming the PRD's direction). Everything else is a mechanical extension of patterns already in the repo (`ChatApiService` singleton + mock, `ChangeNotifier` providers, `ChatBubble` composition).

## Architecture Decisions

### AD-1: Compress on pick, not on send
**Context:** FR-4 says "WHEN the send button is tapped THEN the image is resized..." — suggesting compression happens at send. But compressing 5 images synchronously at send would block the "Thinking..." placeholder appearing and delay the streaming UX by 1-2.5s on mid-range devices.
**Decision:** Run `flutter_image_compress` on each image immediately after picking, store the compressed bytes in state, and render thumbnails from the compressed bytes. Send simply base64-encodes the already-compressed bytes and posts.
**Alternatives rejected:** Compress-on-send — simpler state model but adds perceived latency at send and requires a blocking "processing..." state before the streaming UI appears. Rejected because send latency is the most visible UX moment.
**Trade-off:** The pick flow gets heavier (small wait after picker confirms), but send is instant. Oversize-image rejection (FR-4 edge case) happens at pick time, which is better UX than rejecting at send.
**Reversibility:** Easy — internal pipeline, single service, no external contract impact.

### AD-2: `images` as top-level payload field, base64-encoded JPEG strings
**Context:** PRD FR-5 specifies a new top-level JSON field `images`. The current payload has `user`, `query`, and a nested `inputs` map (Dify-style structured context). Placing `images` inside `inputs` would fit Dify conventions for structured variables, but `inputs` is templated in prompts; binary-like content doesn't belong there.
**Decision:** Add `images` as a top-level array of base64-encoded JPEG strings, sibling to `query`. Field is omitted entirely when empty (not present → text-only flow; present → vision flow). Server-team contract: detect presence of top-level `images` to branch.
**Alternatives rejected:** (a) Multipart/form-data — efficient but breaks the single JSON body the streaming helper already expects, and the server would need a content-type branch. (b) Nested under `inputs` — pollutes Dify's variable namespace.
**Trade-off:** ~33% base64 overhead on the wire. Acceptable — typical payload stays under 4 MB after compression.
**Reversibility:** Medium — changing the field name or moving nesting requires a coordinated client + server release.

### AD-3: No new permission-handler dependency
**Context:** `image_picker` handles OS permission prompts for camera and gallery natively on first invocation. Adding `permission_handler` would duplicate work and inflate the dep count.
**Decision:** Rely on `image_picker`'s built-in permission flow. Add only Info.plist keys (iOS) and camera permission (Android manifest). Gallery permission on Android is handled automatically by `image_picker` (photo picker on Android 13+, legacy permission on <13).
**Alternatives rejected:** Add `permission_handler` to unify iOS/Android permission UX — rejected because it adds surface area without clear wins; if we hit platform-specific gaps later, we revisit.
**Trade-off:** Less fine-grained control over permission-denied UX (we can only detect denial post-tap via a null return from the picker). Acceptable for v1.
**Reversibility:** Easy — adding `permission_handler` later is a pure addition, non-breaking.

### AD-4: `ChatMessage` carries a list of compressed byte blobs for rendering
**Context:** The user bubble needs to render thumbnails of what was sent. Options: store original file paths (transient — picker cache can be cleared), store compressed bytes in memory, or copy to app's private directory.
**Decision:** `ChatMessage` gains a nullable `List<Uint8List>? imageBytes` field holding the already-compressed JPEG bytes. Rendered via `Image.memory`. Not persisted to disk, not serialized in `toJson` (parallels the existing transient-field pattern used by `Record.suggestedCategory`).
**Alternatives rejected:** (a) File paths — break if the picker's cache is evicted. (b) Copy to app-private storage — requires cleanup, adds a persistence layer we don't need.
**Trade-off:** Memory cost — 5 × ~500 KB = ~2.5 MB per outgoing message held for chat lifetime. Dropped on app restart (acceptable — chat history is server-owned for text, and images are ephemeral previews anyway).
**Reversibility:** Easy — can swap to disk-backed paths later without touching the network layer.

### AD-5: Small-image pass-through rule (resolves PRD W3)
**Context:** PRD W3 flagged an ambiguous OR in FR-4: "not re-encoded (or re-encoded losslessly enough)."
**Decision:** Images whose longest edge is ≤1600px AND whose byte size is ≤500 KB bypass re-encoding. All others go through the full resize+re-encode pipeline. HEIC always re-encodes (must become JPEG for server compatibility).
**Alternatives rejected:** Re-encode everything unconditionally — simpler but wastes CPU on already-small images. Rejected for battery/UX on low-end devices.
**Trade-off:** Two code paths to test, but the pass-through path is trivial (read bytes + skip compression).
**Reversibility:** Trivial — change a constant.

### AD-6: All-images-fail send behavior (resolves PRD W4)
**Context:** PRD W4 flagged the missing edge case when every attached image is rejected post-compression.
**Decision:** If after compression zero valid images remain AND the caption text is empty, send is blocked with an inline error. If the caption is non-empty, send proceeds as a text-only message (the user's intent to communicate is preserved). Any rejected images are removed from the preview row before send with an inline error per rejected item.
**Alternatives rejected:** Always block send when any image failed — frustrates users whose caption still has value. Rejected.
**Trade-off:** Slight UX asymmetry between "text + failed images" (sends) vs. "only failed images" (blocks).
**Reversibility:** Trivial — one branch in the send handler.

## Technical Approach

### Service layer

**`lib/services/image_processing_service.dart`** (new). Singleton with `setMockInstance` (matches `ChatApiService` pattern). Responsibilities:
- `processPickedImage(XFile) → Future<ProcessedImage>` — reads bytes, auto-rotates via EXIF, decides pass-through vs. full pipeline (AD-5), runs `flutter_image_compress` (max edge 1600, JPEG Q85), returns `ProcessedImage(bytes: Uint8List, sizeBytes: int)`. Throws `OversizeImageException` if post-compression bytes >1.5 MB.
- `toBase64(Uint8List bytes) → String` — trivial wrapper; exists for mockability and clarity at call sites.
- No state; pure computation.

**`lib/services/image_picker_service.dart`** (new, thin). Wraps `image_picker`:
- `pickFromCamera() → Future<XFile?>` and `pickFromGallery({int maxCount}) → Future<List<XFile>>`.
- Enforces the 5-image cap at call sites (the widget tracks remaining slots, passes `maxCount` down).
- Exists primarily so the widget layer can be unit-tested with mocktail without hitting native plugins.

### Model layer

**`lib/models/chat_message.dart`** (modify). Add nullable `List<Uint8List>? imageBytes`, update `copyWith` and constructor. `toJson` / `fromJson` ignore the field (transient — parallels `Record.suggestedCategory`). No migration concerns (chat messages aren't persisted to SQLite).

### Network layer

**`lib/services/chat_api_service.dart`** (modify). Extend `streamChat` with an optional positional/named parameter `List<String>? imagesBase64`. When non-null and non-empty, add top-level `'images': imagesBase64` to the outbound map (AD-2). When null or empty, the key is omitted — preserving the existing text-only payload exactly. No change to response parsing.

### Provider layer

**`lib/providers/chat_provider.dart`** (modify). `sendMessage(String content, {List<Uint8List>? imageBytes})`:
- Guard: if `content` is empty AND `imageBytes` is null/empty → return (no-op).
- Build user `ChatMessage` with both `content` and `imageBytes`.
- In `_handleStream`, map bytes → base64 via `ImageProcessingService.toBase64` before calling `ChatApiService().streamChat(..., imagesBase64: ...)`.
- All existing streaming / parsing / error paths unchanged.

### UI layer

**`lib/screens/home/tabs/chat_tab.dart`** (modify). Add:
- A trailing `IconButton(Icons.add_photo_alternate_outlined)` inside the existing pill-shaped `TextField` container, before the `TextField` or as an `InputDecoration.suffixIcon` (whichever is cleaner visually with the existing padding).
- On tap: `showModalBottomSheet` with two options ("Take photo", "Choose from library").
- Above the input row (below suggested prompts), conditionally render `_ImagePreviewStrip` — a horizontal row of thumbnails (`Image.memory` with rounded corners) each with a corner "x" to remove. Shows helper text "Up to 5 images" when any image is attached.
- On pick: call `ImagePickerService` → `ImageProcessingService.processPickedImage` per image in parallel (`Future.wait`) → append successful ones to a local `List<Uint8List>` in state; show inline error banners for rejected ones (timed dismiss).
- `_handleSend`: pass `imageBytes` to `ChatProvider.sendMessage`, then clear the local list.
- Send-button enabled when `text.isNotEmpty || imageBytes.isNotEmpty` (updated from the current `text.isNotEmpty`).

**`lib/components/chat_bubble.dart`** (modify). For user role, above the existing text container, render a `Wrap` of thumbnails from `message.imageBytes` (each tappable → fullscreen viewer). Visual: rounded-corner thumbnails at ~96×96, max 3-across before wrapping. No changes to assistant-role rendering.

**`lib/components/image_viewer.dart`** (new). Simple fullscreen `Scaffold(backgroundColor: Colors.black)` with an `InteractiveViewer` wrapping `Image.memory` — provides pinch-zoom and pan for free. Tap outside or back button to dismiss. Single-image scope (matches PRD's "at minimum a simple fullscreen preview").

### Platform setup

- **iOS** `ios/Runner/Info.plist`: add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` with user-facing copy ("Wally needs camera access to capture receipts for logging transactions.").
- **Android** `android/app/src/main/AndroidManifest.xml`: add `<uses-permission android:name="android.permission.CAMERA" />`. Gallery access handled by `image_picker`'s photo picker on API 33+, automatic legacy `READ_EXTERNAL_STORAGE` fallback handled by the plugin on older APIs.
- **pubspec.yaml**: add `image_picker: ^1.1.2` and `flutter_image_compress: ^2.3.0` (latest stable at time of writing — check pub.dev before pinning).

### Error handling

All failure modes funnel into existing patterns — no new UI:
- Picker denial / cancel → silent, no action.
- Compression failure / oversize → inline banner in the preview strip, image removed from the list.
- Send-time exception (network, auth) → existing `ScaffoldMessenger.showSnackBar` in `chat_tab._handleSend`'s catch block.
- Stream `onError` → existing behavior (assistant message content appended with `\nError: ...`), unchanged.

## Traceability Matrix

| PRD Requirement                         | Epic Coverage                                                  | Task(s)    | Verification                   |
| --------------------------------------- | -------------------------------------------------------------- | ---------- | ------------------------------ |
| FR-1 Attachment entry point             | UI layer / `chat_tab.dart` trailing icon                       | T5         | Widget test + manual QA        |
| FR-2 Lazy permission request            | AD-3 (no permission-handler), picker on first tap              | T3, T5     | Manual QA cold-launch check    |
| FR-3 Multi-select with 5-cap            | `ImagePickerService.pickFromGallery(maxCount)` + widget state  | T3, T5     | Widget test (mock picker)      |
| FR-4 Compression pipeline               | `ImageProcessingService`, AD-5 pass-through, AD-6 oversize     | T2         | Unit tests w/ fixture images   |
| FR-5 `images` field on `/streaming`     | AD-2 top-level field + `ChatApiService.streamChat` change      | T4         | Unit test w/ mock `APIHelper`  |
| FR-6 Outgoing bubble renders thumbnails | `chat_bubble.dart` + `image_viewer.dart`                       | T6         | Widget test + manual QA        |
| FR-7 Error bubble reuse                 | Existing `_handleStream` onError path unchanged                | T4, T7     | Integration test (mock server) |
| NTH-1 In-app camera                     | Deferred                                                       | —          | —                              |
| NTH-2 Retry button                      | Deferred                                                       | —          | —                              |
| NFR-1 Upload size budget                | AD-5 pass-through + 1.5 MB cap → 5 × 1.5 MB max                | T2         | Unit test + manual payload log |
| NFR-2 Compression perf ≤2.5s            | Native `flutter_image_compress` + parallel `Future.wait`       | T2, T5     | Manual timing on mid-range     |
| NFR-3 Cross-platform parity             | Platform setup (Info.plist + manifest) + native plugins        | T1         | Manual QA on iOS + Android     |
| NFR-4 No permission at launch           | AD-3 lazy prompt                                               | T5         | Manual QA cold-launch check    |

## Implementation Strategy

### Phase 1: Foundation (Day 0-1)
- **T1** — Dependencies + platform manifests. Everything downstream depends on `image_picker` and `flutter_image_compress` being resolvable and the permission strings being in place.
- **Exit criterion:** `fvm flutter pub get` succeeds; iOS and Android debug builds launch without permission-related crashes.

### Phase 2: Core (Day 1-4, parallel)
- **T2** — Image processing service (compression + base64 + pass-through + oversize detection). Pure-logic; easiest to unit-test first, blocks downstream consumers.
- **T3** — Image picker service wrapper. Thin, can proceed in parallel with T2.
- **T4** — Model + provider + API wire-up (`ChatMessage.imageBytes`, `ChatProvider.sendMessage` signature, `ChatApiService` payload extension). Depends on T2 + T3 being callable.
- **Exit criterion:** Can programmatically construct a user `ChatMessage` with images, call `ChatProvider.sendMessage`, and observe the correctly-formed payload in a mocked `APIHelper.postStream`.

### Phase 3: UI + Polish (Day 4-7, parallel)
- **T5** — Chat input attachment UI (icon, bottom sheet, preview strip, removal, send wiring). Depends on T3 (picker) + T4 (provider signature).
- **T6** — Outgoing bubble rendering + fullscreen viewer. Depends only on T4 (model change). Fully parallel with T5.
- **T7** — Integration test + manual QA sweep across iOS/Android, HEIC, oversize, denied permissions.
- **Exit criterion:** Happy path (pick → preview → send → assistant reply with records) verified manually on both platforms; integration test green; no permission prompt on cold launch.

## Task Breakdown

##### T1: Dependencies and platform permission manifests
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Add `image_picker` and `flutter_image_compress` to `pubspec.yaml`. Add `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` to `ios/Runner/Info.plist` with Vietnamese + English copy. Add `<uses-permission android:name="android.permission.CAMERA" />` to `android/app/src/main/AndroidManifest.xml`. Run `fvm flutter pub get` and verify a debug build boots on both platforms.
- **Key files:** `pubspec.yaml`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`
- **PRD requirements:** NFR-3
- **Key risk:** Latest `image_picker` / `flutter_image_compress` may have Flutter SDK version constraints incompatible with `^3.9.2` — verify before pinning.
- **Interface produces:** Usable `image_picker` and `flutter_image_compress` APIs for downstream tasks.

##### T2: `ImageProcessingService` — compression + encode + pass-through
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Create `lib/services/image_processing_service.dart` as a singleton (mirrors `ChatApiService` pattern with `setMockInstance`). Implement `processPickedImage(XFile)` that reads bytes, applies AD-5 pass-through rule (longest edge ≤1600 AND size ≤500KB → bypass), otherwise runs `flutter_image_compress` (max edge 1600, JPEG quality 85, auto-rotate). Throw `OversizeImageException` when post-compression size >1.5MB. Expose `toBase64(bytes)`. Write unit tests in `test/services/image_processing_service_test.dart` with fixture images (small JPEG, large JPEG, HEIC, pathologically-incompressible image) in `test/fixtures/images/`.
- **Key files:** `lib/services/image_processing_service.dart`, `lib/services/services.dart`, `test/services/image_processing_service_test.dart`, `test/fixtures/images/*`
- **PRD requirements:** FR-4, NFR-1, NFR-2
- **Key risk:** HEIC decoding on Android via `flutter_image_compress` is less battle-tested than iOS; test explicitly with an HEIC fixture on both platforms before declaring NFR-3 met.
- **Interface produces:** `ImageProcessingService.processPickedImage() → ProcessedImage` consumed by T5; `toBase64()` consumed by T4.

##### T3: `ImagePickerService` wrapper
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T1 | **Complexity:** simple
- **What:** Create `lib/services/image_picker_service.dart` wrapping `image_picker`: `pickFromCamera() → Future<XFile?>` and `pickFromGallery({required int maxCount}) → Future<List<XFile>>`. Enforce `maxCount` by trimming returned list and surfacing no errors for extras (UI shows the "Up to 5 images" hint). Singleton + `setMockInstance` pattern for testability. No platform permission handling here — rely on `image_picker`'s native behavior (AD-3).
- **Key files:** `lib/services/image_picker_service.dart`, `lib/services/services.dart`, `test/services/image_picker_service_test.dart`
- **PRD requirements:** FR-2, FR-3
- **Key risk:** `image_picker` API changes between major versions — pin to a known-working version in T1.
- **Interface produces:** Picker functions consumed by T5.

##### T4: Model, provider, and API payload wiring
- **Phase:** 2 | **Parallel:** no | **Est:** 1d | **Depends:** T2 | **Complexity:** moderate
- **What:** Modify `lib/models/chat_message.dart` to add `List<Uint8List>? imageBytes` as a transient field (not in `toJson`/`fromJson`, updated in `copyWith`). Modify `lib/services/chat_api_service.dart`: `streamChat` takes a new optional `List<String>? imagesBase64` param; when non-empty, adds `'images': imagesBase64` at the top level of the outbound map (AD-2), otherwise field is absent. Modify `lib/providers/chat_provider.dart`: `sendMessage(String content, {List<Uint8List>? imageBytes})` — builds the user `ChatMessage` with both, base64-encodes the bytes in `_handleStream` via `ImageProcessingService.toBase64`, and passes to `streamChat`. All existing stream parsing + error paths unchanged. Update tests in `test/providers/chat_provider_test.dart` for the new signature; add a new test verifying the outbound payload shape with mocked `ChatApiService`.
- **Key files:** `lib/models/chat_message.dart`, `lib/services/chat_api_service.dart`, `lib/providers/chat_provider.dart`, `test/providers/chat_provider_test.dart`, `test/services/chat_api_service_test.dart`
- **PRD requirements:** FR-5, FR-7
- **Key risk:** Existing `ChatProvider` callers (chat_tab.dart and tests) need signature update — forgetting one produces compile errors but that's the happy fail mode.
- **Interface receives from T2:** `ImageProcessingService.toBase64()`.
- **Interface produces:** Updated `ChatProvider.sendMessage` signature consumed by T5; updated `ChatMessage.imageBytes` consumed by T6.

##### T5: Chat input attachment UI
- **Phase:** 3 | **Parallel:** yes | **Est:** 1.5d | **Depends:** T3, T4 | **Complexity:** complex
- **What:** Modify `lib/screens/home/tabs/chat_tab.dart`. Add a trailing photo icon inside the existing `TextField` pill container. Tap opens a `showModalBottomSheet` with "Take photo" and "Choose from library" rows. On pick, call `ImagePickerService` then process each `XFile` in parallel via `Future.wait` on `ImageProcessingService.processPickedImage`; append successful results to a local `List<Uint8List> _pendingImages` and render a horizontal preview strip above the input (thumbnails from `Image.memory` with remove "x"). Show inline error banners for rejected images (oversize, compression failure), auto-dismissed after ~3s. Show helper text "Up to 5 images" when any image is attached; block picking more when count ≥5. Enable send button when `_controller.text.isNotEmpty || _pendingImages.isNotEmpty`. On send, pass `imageBytes: _pendingImages` to `ChatProvider.sendMessage`, then clear `_pendingImages`. Apply AD-6: block send only when both are empty post-rejection. Uses existing `LocaleProvider` for user-facing strings.
- **Key files:** `lib/screens/home/tabs/chat_tab.dart`, `lib/components/image_preview_strip.dart` (new — extracted component), `lib/l10n/*` (add new strings if any), `test/screens/home/tabs/chat_tab_test.dart`
- **PRD requirements:** FR-1, FR-2, FR-3, FR-4 (send-block edge), NFR-4
- **Key risk:** Fitting the new icon into the existing rounded `TextField` container without visual regression — current layout is tight. Consider moving the send button and image icon outside the pill if crowded.
- **Interface receives from T3:** `ImagePickerService.pickFromCamera() / pickFromGallery()`.
- **Interface receives from T4:** `ChatProvider.sendMessage(content, imageBytes: ...)`.

##### T6: Outgoing bubble rendering + fullscreen viewer
- **Phase:** 3 | **Parallel:** yes | **Est:** 1d | **Depends:** T4 | **Complexity:** moderate
- **What:** Modify `lib/components/chat_bubble.dart`: for user-role messages with non-null `message.imageBytes`, render a `Wrap` of 96×96 rounded-corner thumbnails (via `Image.memory`) above the existing text container. Each thumbnail is tappable to open fullscreen. Create `lib/components/image_viewer.dart`: a fullscreen `Scaffold(backgroundColor: Colors.black)` with `InteractiveViewer` wrapping `Image.memory(bytes)` (free pinch-zoom + pan), dismiss via back button or tap-outside. No hero animation in v1 (kept simple). Register the component in `lib/components/components.dart`. Add a widget test in `test/components/chat_bubble_test.dart` verifying thumbnails render and tap opens the viewer.
- **Key files:** `lib/components/chat_bubble.dart`, `lib/components/image_viewer.dart`, `lib/components/components.dart`, `test/components/chat_bubble_test.dart`
- **PRD requirements:** FR-6
- **Key risk:** Large in-memory images in long chat histories cause scroll jank — at 5 images × ~500KB each × N messages, memory can climb. Acceptable for v1 (chat is ephemeral in practice), but flag for post-launch observation.
- **Interface receives from T4:** `ChatMessage.imageBytes` field.

##### T7: Integration test + cross-platform QA
- **Phase:** 3 | **Parallel:** no | **Est:** 1d | **Depends:** T5, T6 | **Complexity:** moderate
- **What:** Add `tests/integration/epic_image-input/send_with_images_test.dart` — drives the chat flow end-to-end with a mocked `ChatApiService` (via `setMockInstance`) to verify: picked images compress + render as thumbnails, send emits a mock request carrying `images: [...]`, streamed response parses records unchanged, user bubble shows thumbnails. Perform manual QA sweep: cold-launch no-prompt check (NFR-4), iOS HEIC pick, Android camera capture, 5-image cap (attempt to pick 6), denied permission graceful path, oversize image inline error, all-images-fail blocks send (AD-6), timeout surfaces existing error bubble (FR-7). Record results in a short QA notes file under `.claude/epics/image-input/qa-notes.md`.
- **Key files:** `tests/integration/epic_image-input/send_with_images_test.dart`, `.claude/epics/image-input/qa-notes.md`
- **PRD requirements:** FR-7, NFR-3, NFR-4 (plus end-to-end coverage of FR-1..FR-6)
- **Key risk:** Manual QA across iOS + Android is the bottleneck. Plan for ~4 hours of physical-device testing.
- **Interface receives from T5, T6:** End-to-end chat flow.

## Risks & Mitigations

| Risk                                                                   | Severity | Likelihood | Impact                                      | Mitigation                                                                                                                         |
| ---------------------------------------------------------------------- | -------- | ---------- | ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Slow-network timeouts on 5-image uploads                               | High     | Medium     | Users see error bubbles on bad Wi-Fi        | AD-5 pass-through + 1.5 MB per-image cap keeps worst-case payload at ~10 MB base64. Error bubble reuses existing pattern — no silent drop. Consider a client timeout bump post-launch if metrics justify. |
| Server vision pipeline returns low-quality extractions                 | High     | Medium     | Hurts extraction-reliability success criterion | Client treats server as dumb contract — no client-side fallback logic. Server team owns extraction quality; surface failures via existing error bubble. Flag early via manual QA with real receipts. |
| HEIC decoding on Android via `flutter_image_compress` is less tested   | Medium   | Low        | HEIC uploads fail or produce corrupt JPEGs  | T2 unit tests include HEIC fixture. T7 manual QA explicitly covers HEIC-from-iCloud path on Android. Fallback: reject undecodable images with inline error (doesn't upload garbage). |
| Fitting the new icon into the existing pill-shaped `TextField`         | Medium   | Medium     | Visual regression in the chat input         | T5 risk noted inline. If layout conflicts, move image + send icon outside the pill and restyle — consult existing design mocks. Worst case is cosmetic.          |
| Memory pressure from in-memory `Uint8List` storage in `ChatMessage`    | Medium   | Low        | Jank on low-RAM devices after many turns    | AD-4 notes the cost. Cap image size + rely on 5-per-message limit. Profile on a 2GB-RAM Android if reports surface.               |
| `image_picker` API breaking-change between versions                    | Low      | Low        | Build breaks on pub upgrade                 | Pin to an exact minor in T1. Document in epic that upgrades need a smoke-test pass on T5 + T7 scenarios.                          |
| Compression on pick (AD-1) still produces a noticeable delay on pick   | Low      | Medium     | Pick → preview gap feels slow on old devices | T5 shows a lightweight spinner overlay on each thumbnail slot until compression resolves. `Future.wait` runs images in parallel; native plugin keeps wall time ≤2.5s (NFR-2). |

## Dependencies

- **Server `/streaming` vision extraction support** — server team — *Status: pending.* Server must detect top-level `images` array in the request body and branch to the vision pipeline, returning the existing record-array JSON (`--//--` delimited). Gate the client release on this readiness.
- **`image_picker` plugin** — pub.dev / maintained — *Status: pending install (T1).* Exact version pin in T1.
- **`flutter_image_compress` plugin** — pub.dev / maintained — *Status: pending install (T1).*
- **Existing `ChatApiService` + `ChatProvider` + `ChatBubble` infrastructure** — internal — *Status: resolved.* Reused as-is; this epic extends them.
- **Translation strings** — internal — *Status: pending.* New user-facing strings ("Take photo", "Choose from library", "Up to 5 images", oversize error) need entries in the locale files consumed by `LocaleProvider`.

## Success Criteria (Technical)

| PRD Criterion                            | Technical Metric                                            | Target                         | How to Measure                                                                                          |
| ---------------------------------------- | ----------------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------- |
| Adoption ≥25% of active chat users       | Server-side count of `/streaming` requests with `images`    | ≥25% / DAU over 4 weeks        | Server-team analytics on `images` field presence (coordination dep; tracked as PRD warning W2)           |
| Extraction reliability ≥85%              | `/streaming` responses w/ non-empty record array            | ≥85% of image-bearing requests | Server-team logs comparing `images`-carrying requests to resulting record persistence events            |
| Upload success rate ≥97%                 | Client-side counter of send-attempts vs. stream completions | ≥97%                           | QA bench measurement (no analytics infra shipping with v1 — acknowledged PRD warning W1; revisit post-launch) |
| Permission timing compliance (0 at launch) | No prompt on cold launch                                    | 0 prompts                      | T7 manual QA on both platforms                                                                          |
| Compression effectiveness                | Post-compression size distribution                          | Median ≤800 KB, p95 ≤1.5 MB    | Debug-log pre/post sizes during QA; spot-check 20 real-world receipts (W1 acknowledged)                 |
| Compression performance                  | Wall time for parallel 5-image compression                  | ≤2.5s on Pixel 6a / iPhone 12  | Manual timing in T7 on reference devices                                                                |

## Estimated Effort

- **Total:** ~5.5 dev-days across 7 tasks.
- **Critical path:** T1 → T2 → T4 → T5 → T7 = ~4.5 days.
- **Parallel headroom:** T3 (with T2), T6 (with T5) can shave ~1 day if two developers run them concurrently.
- **Phases timeline (single dev):** Phase 1 → 0.5d, Phase 2 → 2.5d, Phase 3 → 2.5d.

## Deferred / Follow-up

- **NTH-1: In-app camera with receipt edge detection.** High implementation cost; native camera is sufficient for v1. Revisit after v1 metrics show capture quality issues.
- **NTH-2: Retry-failed-upload button.** Re-picking works; adds state-management complexity best deferred until real failure rates are observed in production.
- **Client-side telemetry (addresses PRD W1/W2).** No analytics framework ships with v1. If success criteria need quantitative validation beyond QA, scope a small telemetry epic post-launch.
- **Design system integration.** No `.claude/designs/image-input/` directory exists at epic time; visual polish follows existing `chat_bubble.dart` and `chat_tab.dart` patterns inline.

## Tasks Created

| #   | Task                                               | Phase | Parallel | Est.  | Depends On        | Status |
| --- | -------------------------------------------------- | ----- | -------- | ----- | ----------------- | ------ |
| 170 | Dependencies and platform permission manifests     | 1     | no       | 0.5d  | —                 | open   |
| 171 | ImageProcessingService — compression + encode      | 2     | yes      | 1d    | 001               | open   |
| 172 | ImagePickerService wrapper                         | 2     | yes      | 0.5d  | 001               | open   |
| 173 | Model, provider, and API payload wiring            | 2     | no       | 1d    | 010               | open   |
| 174 | Chat input attachment UI                           | 3     | yes      | 1.5d  | 011, 012          | open   |
| 175 | Outgoing bubble rendering + fullscreen viewer      | 3     | yes      | 1d    | 012               | open   |
| 176 | Integration verification + cross-platform QA       | 3     | no       | 1d    | 001,010,011,012,020,021 | open |

### Summary

- **Total tasks:** 7
- **Parallel tasks:** 4 (T171, T172 in Phase 2; T174, T175 in Phase 3)
- **Sequential tasks:** 3 (T170, T173, T176)
- **Estimated total effort:** ~5.5d
- **Critical path:** T170 → T171 → T173 → T174 → T176 (~4.5d)

### Dependency Graph

```
T170 ──→ T171 ──→ T173 ──→ T174 ──→ T176
     └─→ T172 ──────────────────────────→ T176
                   T173 ──→ T175 ────────→ T176

Critical path: T170 → T171 → T173 → T174 → T176 (~4.5d)
Parallel savings: T172 with T171 | T175 with T174 (~saves 1d with 2 devs)
```

### PRD Coverage

| PRD Requirement             | Covered By      | Status     |
| --------------------------- | --------------- | ---------- |
| FR-1: Attachment entry      | T174            | ✅ Covered  |
| FR-2: Lazy permission       | T172, T174      | ✅ Covered  |
| FR-3: 5-image cap           | T172, T174      | ✅ Covered  |
| FR-4: Compression pipeline  | T171, T174      | ✅ Covered  |
| FR-5: /streaming `images`   | T173            | ✅ Covered  |
| FR-6: Bubble thumbnails     | T175            | ✅ Covered  |
| FR-7: Error bubble reuse    | T173, T176      | ✅ Covered  |
| NFR-1: Upload size budget   | T171            | ✅ Covered  |
| NFR-2: Compression perf     | T171, T174      | ✅ Covered  |
| NFR-3: Cross-platform       | T170, T176      | ✅ Covered  |
| NFR-4: No prompt at launch  | T172, T176      | ✅ Covered  |
| NTH-1: In-app camera        | Deferred        | ⏭ Deferred |
| NTH-2: Retry button         | Deferred        | ⏭ Deferred |
