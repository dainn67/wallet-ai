# Server Spec: `occurred_at` in Chat Record JSON

This doc tells the server (`../chatbot-flow-server/`, WalletAI / wallyai scope) how to extract the event time from the user's message and return it to the mobile client.

## Context

Users often log records hours after the fact — "Breakfast at 9am $10" typed at 10pm. Without an event time, every record gets stamped with its save time and lands in the wrong bucket. The client now has an editable `occurredAt` field, but falls back to "now" unless the server provides one.

## Request: what the client sends

The existing chat request already includes a `current_datetime` input. As of this spec it uses **ISO-8601 local time, seconds precision, no timezone suffix**:

```
current_datetime: "2026-04-21T22:00:00"
```

That's exactly the shape the server should produce for `occurred_at` — the AI just needs to modify the date/time parts of the same string.

## Response: what the server adds

Add an **optional** `occurred_at` field to each record in the streamed JSON array that follows the `--//--` delimiter:

```json
{
  "type": "expense",
  "amount": 10,
  "currency": "USD",
  "category_id": 1,
  "money_source_id": 1,
  "description": "Breakfast",
  "occurred_at": "2026-04-21T09:00:00"
}
```

**Format:** ISO-8601 local time string, same shape as `current_datetime`. No timezone suffix, no fractional seconds.

**Client parsing** (reference): `DateTime.tryParse(raw)?.millisecondsSinceEpoch`. If the field is missing, malformed, or not a string, the client falls back to `DateTime.now()` — same as pre-spec behavior.

## Extraction rules (for the AI prompt)

The AI receives `current_datetime` and the user message. It should produce `occurred_at` using `current_datetime` as the reference point:

1. **Explicit time, same day implied** — "Breakfast at 9am $10" → replace the time portion of `current_datetime`.
   - `current_datetime: 2026-04-21T22:00:00` + "9am" → `2026-04-21T09:00:00`
2. **"Yesterday" / "last night" / relative days** — subtract the appropriate number of days from `current_datetime`, then apply the spoken time.
   - `current_datetime: 2026-04-21T22:00:00` + "breakfast 9am yesterday" → `2026-04-20T09:00:00`
3. **Only time, no day marker** — assume today. If the resulting time is in the *future* relative to `current_datetime`, still pick today (users log past events, never future ones).
4. **Only a day marker, no time** — pick a neutral default based on meal context: breakfast=`08:00`, lunch=`12:00`, dinner=`19:00`. If no context at all, use `12:00`.
5. **Explicit date + time** — "Dinner on 20/4 at 8pm" → `2026-04-20T20:00:00` (year inferred from `current_datetime`).
6. **No time signal in the message — omit `occurred_at` entirely. This is mandatory, not optional.**
   - Examples that have NO time signal: `"10 bucks for coffee"`, `"Grocery 450k"`, `"Bought clothes yesterday"` ← wait, "yesterday" IS a signal → rule 2; but `"Paid rent this month"` has no specific day → omit.
   - Do NOT invent a time, do NOT default to noon, do NOT copy `current_datetime`. Just leave the field out of the JSON object.
   - When the field is absent, the client saves the record with `occurred_at` equal to its own internal save time (same millisecond as `last_updated`). That is the correct, desired fallback.

Principle: emit `occurred_at` only when the user was reasonably explicit. Silent omission is safer than a wrong guess — the user can always correct via the in-app date/time picker.

## What *not* to do

- Do NOT compute millisecondsSinceEpoch — LLMs are unreliable at epoch math. Always emit the ISO-8601 string.
- Do NOT add a timezone suffix (`Z`, `+07:00`). The client sends local time and expects local time back.
- Do NOT invent `occurred_at` when the message has no time cue (e.g. "10 bucks for coffee"). Omit the field instead.
- Do NOT touch `last_updated` — the client manages it as an internal audit timestamp.

## Why a tool call isn't needed

All the AI needs — the current date, time, and day of week — is already in the `current_datetime` input string. Relative expressions like "yesterday", "last night", "this morning", "2 days ago" resolve via simple date arithmetic, which current-generation LLMs handle reliably when the reference time is injected into the prompt.

Tool calls would only pay off for edge cases like "3 weeks ago Thursday" (multi-step date math). Those are rare in a personal-finance flow, and users can correct misses with the picker — so ship prompt-injection first and add a `resolve_date` tool later only if you see recurring failure patterns.

## Client behavior (for reference)

- **Sorting**, **monthly filter**, **record-card date**, **records-tab date dividers**, **home-widget totals**, and **AI pattern analysis** all use `occurredAt`.
- **`last_updated`** is a local audit field — never sent by the server.
- Users can always override the AI's guess via `EditRecordPopup`'s date+time picker.
