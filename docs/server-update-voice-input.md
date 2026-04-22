# Server Requirements: Voice Input Support

## Context

The WalletAI app is adding an in-app voice recording feature. Users tap a mic icon, speak an expense (up to 30 seconds), and the audio is sent to the `/streaming` endpoint. The server must detect the audio field, route to a voice-aware LLM prompt, and return the same `message--//--[records_json]` SSE format the client already parses.

---

## API Changes Required

### Endpoint
`POST /wallet-ai-chatbot` (unchanged)

### New Request Field

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `audio` | `string` | No | Base64-encoded audio file recorded in-app. Omitted entirely when no voice message is sent. Max ~30 seconds. |

The `query` field may be an empty string when the user records audio without typing. Both `audio` and `query` can be present simultaneously (user typed text and also recorded audio — treat the text as additional context for interpreting the audio).

All other existing fields (`user`, `inputs`, `conversation_id`, `provider`, `images`) are unchanged.

> **Note:** `audio` and `images` are mutually exclusive in this iteration — the client will not send both in the same request.

### Audio Format

The client will encode the audio in a format Gemini accepts natively. Exact format (AAC, FLAC, OGG, WAV) TBD based on what the `record` Flutter package produces and what Gemini's API supports. The server should treat the field as opaque base64 and forward it to the LLM as an inline audio part — no server-side transcoding needed.

---

## Behavior Requirements

### When `audio` is absent
Existing flow — no change.

### When `audio` is present (and `query != "INIT_GREETING"`)
The server must:
1. Decode the base64 audio and pass it to the LLM alongside the text prompt (similar to how `images` is handled).
2. Instruct the LLM to listen to the audio and extract financial records from it.
3. Treat `query` (if non-empty) as additional context or instruction alongside the audio.
4. Return the response in the **same format** as all other flows: `message--//--[records_json]` SSE stream.

### `INIT_GREETING` with audio
Audio should be ignored — run the normal greeting flow.

### When the AI cannot interpret the audio
The LLM should return a natural language response indicating it couldn't understand (no records extracted). The client will detect this and show the error message "I didn't catch that. Please try again." — no special error code or HTTP status needed from the server.

---

## Prompt Behavior

The voice prompt should:
- Instruct the model it is receiving an audio recording of a user stating an expense or income.
- Extract the same record fields as the text flow: `source_id`, `amount`, `category_id`, `description`, `type`, `suggested_category`, `occurred_at`.
- If the audio is unclear, silent, or contains no financial information, return a friendly message with an empty records array (`[]`) — do not fabricate records.

---

## Response Format
Unchanged. The client parser expects the same SSE stream:
```
your_message--//--[{"source_id": "", "amount": "", "category_id": "", "description": "", "type": "", "suggested_category": null, "occurred_at": null}, ...]
```

Empty records for unrecognized audio:
```
I didn't catch that clearly. Could you try again?--//--[]
```

---

## Notes
- Gemini natively supports audio input as inline parts (same multimodal API used for images).
- No new endpoint needed.
- No response format change.
- Verify Gemini's supported audio MIME types and max inline size before implementing — align with the client's chosen encoding format.
