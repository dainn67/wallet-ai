# QA Checklist — image-input (epic)

Branch: epic/image-input

## Prerequisites

- **iOS**: physical device or simulator running iOS 14+. Start fresh (no previously granted permissions).
- **Android**: device or emulator. Test on **API 33+** (Android 13 photo picker) AND on one **API 29–32** device (legacy gallery + CAMERA permission flow).
- **Server**: ensure the `/streaming` endpoint supports the new top-level `images` field. If not yet deployed, S7/S8 sends will result in a server-side error bubble — that is expected. Flag with the server team before running those scenarios.
- Build and install a fresh **debug** build: `fvm flutter build apk --debug` / `fvm flutter build ios --debug --no-codesign`.

---

## Scenarios

### S1 — No permission prompt at cold launch

**Steps**
1. Fresh install. Open app. Navigate to Chat tab.
2. Observe the screen for 3 seconds without tapping anything.

**Expected**: No permission dialog appears (camera or photo library). Attachment icon is visible in the input area.

---

### S2 — Attachment sheet opens

**Steps**
1. In Chat tab, tap the attachment icon (paperclip / photo icon) in the text input row.

**Expected**: A bottom sheet slides up with two options: "Take photo" and "Choose from library".

---

### S3 — Camera permission prompt (first use)

**Steps**
1. Tap attachment icon → tap "Take photo".
2. (First time only) System camera-permission dialog appears.
3. Grant permission.

**Expected (iOS)**: Camera UI opens. **Expected (Android <13)**: CAMERA permission dialog, then camera opens. **Expected (Android 13+)**: Camera opens directly (no runtime prompt for camera on 13+).

---

### S4 — Camera capture → thumbnail appears

**Steps**
1. Open camera via "Take photo".
2. Capture a photo.

**Expected**: Camera closes, one thumbnail appears in the preview strip above the text input. Strip shows a small image with an "×" remove button.

---

### S5 — Gallery pick (up to 5)

**Steps**
1. Tap attachment icon → tap "Choose from library".
2. (First time only) Grant photo-library access.
3. Select 3 images.

**Expected**: 3 thumbnails visible in preview strip. Helper area shows thumbnails correctly. "Up to 5 images" helper text or cap behavior is visible if you attempt to add more (see S6).

---

### S6 — 5-cap enforcement

**Steps**
1. From the gallery, attempt to select 6 or more images in one pick session.

**Expected**: Only the first 5 are added to the strip. If the OS picker allows more, the extra are silently discarded. No crash. Attempt to open the picker again when 5 are already selected: the sheet shows a SnackBar "Maximum 5 images per message" and the picker does not open.

---

### S7 — Send images only (no caption)

**Steps**
1. Pick 1–2 images from gallery.
2. Leave the text field empty.
3. Tap the send button.

**Expected**: Send button is active (enabled) while images are pending with empty caption. After send: user bubble appears in the chat list showing the thumbnail(s) with no text below. Strip clears. Text field stays empty.

---

### S8 — Send caption + images

**Steps**
1. Pick 2 images.
2. Type "lunch 50k" in the text field.
3. Tap send.

**Expected**: User bubble shows 2 thumbnails above the "lunch 50k" caption. Assistant "Thinking..." bubble appears. After stream completes: assistant response appears (or an error bubble if server not ready).

---

### S9 — Oversize image rejected

**Steps**
1. Pick a large RAW or uncompressed image (or a photo from burst mode that is several MB).
2. If unavailable, find any image file > 1.5 MB after compression.

**Expected**: A SnackBar appears with text "Image too large after compression". The image is not added to the preview strip. Other images in the same batch (if any) that are within the limit are added normally.

---

### S10 — Small image pass-through (≤ 512 KB)

**Steps**
1. Pick a small screenshot or low-res JPEG (< 512 KB).
2. Send it.

**Expected**: Image is sent without re-encoding (pass-through). No quality degradation visible in the thumbnail. (Verify in Charles proxy / network log that the base64 bytes match the original if tooling is available.)

---

### S11 — HEIC input (iOS only)

**Steps**
1. On iOS, open gallery and select a photo taken in HEIC format (default on modern iPhones).
2. Send with a caption.

**Expected**: No crash. The thumbnail renders correctly. The image is converted to JPEG before send (transparent to the user — verify via proxy if needed).

---

### S12 — Thumbnail tap → fullscreen viewer

**Steps**
1. Send a message with at least one image so it appears in the chat bubble.
2. Tap a thumbnail in the sent user bubble.

**Expected**: A full-screen black-background image viewer opens (`ImageViewer`). Image is displayed centred with `fit: contain`. A back arrow is visible in the top-left.

---

### S13 — Fullscreen viewer: pinch-zoom and dismiss

**Steps**
1. Open the image viewer (S12).
2. Pinch-zoom in to ~3×.
3. Pinch back out.
4. Press the back arrow (or swipe back on iOS).

**Expected**: Zoom works smoothly between 1× and 4×. Back arrow / swipe dismisses the viewer and returns to the chat.

---

### S14 — Remove image from preview strip before send

**Steps**
1. Pick 3 images.
2. Tap the "×" on the second thumbnail.

**Expected**: Second thumbnail is removed. Strip now shows 2 thumbnails. Other thumbnails and order are unaffected.

---

### S15 — Text-only message unaffected

**Steps**
1. Send a plain text message with no images attached.

**Expected**: Text bubble renders exactly as before. No thumbnail row appears. No regressions in text-only flow.

---

### S16 — Attachment icon disabled while streaming

**Steps**
1. Send a message (with or without images) and observe the attachment icon while streaming is active ("Thinking..." shown).

**Expected**: Attachment icon is greyed out / non-interactive while the assistant is streaming. Once streaming ends the icon becomes active again.

---

### S17 — Server error → error bubble

**Steps**
1. Disable network or ensure server returns a 4xx/5xx.
2. Send a message with an image.

**Expected**: The assistant bubble shows the existing error suffix pattern (e.g., "…\nError: …"). No new crash or UI anomaly. This is the same error path as text-only sends.

---

### S18 — Android 13+ photo picker (READ_MEDIA_IMAGES)

**Steps**
1. On Android 13+ device, first use. Tap attachment → gallery.
2. Observe permission dialog.

**Expected**: System photo picker appears (Material You design). No legacy READ_EXTERNAL_STORAGE prompt. Select photos normally.

---

### S19 — Android <13 legacy gallery + permission

**Steps**
1. On Android API 29–32 device, first use. Tap attachment → gallery.
2. Accept READ_EXTERNAL_STORAGE prompt.

**Expected**: Standard gallery UI opens. Photos selectable. Flow identical to S5.

---

### S20 — Camera permission denied

**Steps**
1. Tap attachment → "Take photo" → deny camera permission when prompted.

**Expected**: No crash. Input returns to the normal chat state. The text field and attachment icon remain usable.

---

## Known Gaps / Notes

1. **Server-side `images` field**: Confirm the `/streaming` endpoint accepts the new top-level `images` field before running S7/S8/S17. Until confirmed, S7/S8 will return an error bubble — expected behaviour, not a client bug.
2. **Android permission split**: READ_EXTERNAL_STORAGE vs. READ_MEDIA_IMAGES split at API 33. Ensure the `AndroidManifest.xml` carries both declarations (already handled in task T001). Verify on both API levels (S18, S19).
3. **HEIC detection (S11)**: iOS 14+ image_picker returns HEIC as `image/heic` MIME; the service checks `mimeType` and the `.heic` extension. If the picker returns a different MIME, pass-through kicks in and HEIC bytes are sent raw — this could cause server decode failure. Flag if encountered.
4. **No client-side analytics**: Per PRD warnings W1/W2, no telemetry is wired for image sends in v1. Success metrics are manual-bench only at this stage.
5. **5-cap UI helper text**: The "Up to 5 images" helper was specified in FR-3 but may be rendered as a SnackBar rather than persistent text. Verify the copy is user-friendly on both platforms.
6. **Skipped automated scenarios**: The full ChatApiService body inspection (verifying base64 content and `query`/`images` field structure) is covered in `test/services/chat_api_service_test.dart`, not in the integration widget test — the mock ChatProvider intercepts before bytes reach the API service at the widget-test level.
