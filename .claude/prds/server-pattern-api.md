---
name: server-pattern-api
description: API endpoint to send AI context to the server and background sync logic
status: draft
---

# PRD: server-pattern-api

## Requirements

### 1. API Integration
- Create an API endpoint configuration `POST /api/patterns/sync`
- Or maybe something like `ApiService().post('/api/patterns/sync', data: context)`
- Needs to parse and store the server response: "long-term-user-pattern"

### 2. SharedPreferences Storage
- Use `StorageService` to store:
  - `last_context_sync_time` (int, default -1) -> timestamps of the last successful sync
  - `long_term_user_pattern` (String, default empty) -> the analysis result from server

### 3. Sync Logic (Daily/On App Open)
- When the app opens, check the current time.
- Get `last_context_sync_time`.
- If `last_context_sync_time == -1`: Send initial sync.
- If `last_context_sync_time != -1`:
  - Calculate days from `last_context_sync_time` to "yesterday" (the latest completed day).
  - Example: last send was Monday, today is Friday. Days to sync = Tuesday, Wednesday, Thursday.
  - If there are days to sync, call `AiContextService.getAiContext` for that specific time window.
  - Send to server.
  - If successful, update `last_context_sync_time` to "yesterday" and save `long_term_user_pattern`.

### 4. Update AiContextService.getAiContext
- Update `getAiContext` to easily fetch records for a specific date range, e.g., from `startDate` to `endDate`.
- Or dynamically adjust based on how many days to fetch.

