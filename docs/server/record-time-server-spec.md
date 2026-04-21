# Server Spec: `occurred_at` in Chat Record JSON

This document tells the server (`../chatbot-flow-server/`, WalletAI / wallyai scope) what the mobile client expects so the AI can extract the event time from the user's natural-language message.

## Context
Today the client treats every record as having happened at "now" (`DateTime.now()` on the device). Users often log records hours after the event — "Breakfast at 9am $10" typed at 10pm. The client now has an editable `occurredAt` field (ms since epoch, device-local) but still defaults to "now" unless the server tells it otherwise.

## Contract

Add an optional `occurred_at` field to each record object in the streamed record array that follows the `--//--` delimiter.

```json
{
  "type": "expense",
  "amount": 10,
  "currency": "USD",
  "category_id": 1,
  "money_source_id": 1,
  "description": "Breakfast",
  "occurred_at": 1745212800000
}
```

### Accepted formats
The client will parse `occurred_at` as:
1. **Integer** — milliseconds since Unix epoch (UTC). Preferred.
2. **ISO-8601 string** — e.g. `"2026-04-21T09:00:00+07:00"`. Parsed via `DateTime.parse().millisecondsSinceEpoch`.

If the field is missing or unparseable, the client falls back to `DateTime.now().millisecondsSinceEpoch` (current behavior).

## Extraction rules for the AI prompt

1. **Explicit time in message** — "Breakfast at 9am $10" → resolve `9am` relative to the user's current day. If the time hasn't happened yet today, assume it means today (not tomorrow).
2. **Relative time** — "yesterday", "last night", "this morning", "2 hours ago" → compute relative to the current server time in the user's timezone (if available; otherwise UTC).
3. **Explicit date+time** — "Dinner on 20/4 at 8pm" → combine the date with the time.
4. **Only date, no time** — "Lunch yesterday $15" → pick a neutral default (e.g., 12:00 for lunch, 08:00 for breakfast, 19:00 for dinner based on context words; or just 12:00 if no context).
5. **No time signal at all** — omit the field; the client will default to "now".

The goal is to be right when the user was explicit and silent when they weren't.

## Timezone handling

The mobile client does NOT send its timezone today. The server should use the timezone included in the device's message payload if one is added later; until then, the server may pick a reasonable default (UTC or the AI's best inference from the conversation). The client stores and displays event times in device-local time, so minor timezone skew is acceptable for now.

## Client behavior (for reference)

- **Sorting**, **monthly filter**, **record-card date**, **home-widget totals**, and **AI user-pattern analysis** all use `occurredAt`.
- **`last_updated`** remains a server-invisible audit field (when the row was last written locally).
- Users can always override the AI's time guess via the date+time picker in `EditRecordPopup`.

## Non-goals for the server

- Do NOT touch `last_updated` — the server doesn't know it and shouldn't send it.
- Do NOT filter or bucket records server-side; the client does all filtering.
