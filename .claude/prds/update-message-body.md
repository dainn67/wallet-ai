---
name: update-message-body
description: Enhance chat API requests with category/source context and simplify AI record parsing.
status: complete
priority: P1
scale: medium
created: 2026-03-19T06:30:00Z
updated: 2026-03-19T10:30:00Z
---

# PRD: update-message-body

## Executive Summary
This epic optimizes the communication between the AI assistant and the app by providing the AI with clear context regarding available money sources and record categories. By sending these lists (formatted as `id-Name`) in the `streamChat` request, we enable the AI to return specific IDs directly in its response. This allows us to remove fragile string-matching logic in the app's parser, leading to more reliable record creation and better data integrity.

## Final Summary
All functional and non-functional requirements have been met. `ChatProvider` is now integrated with `RecordProvider` to fetch and send app context (categories and money sources) to the Dify AI. The AI record parser has been refactored to use direct ID mappings, and robust fallback logic is in place. Unit and integration tests have been added to ensure ongoing stability.

## User Stories
**US-1: Contextual Chat Requests**
As an AI Agent, I want to receive a list of available money sources and categories in every chat request so that I can provide structured data that matches the app's schema.

Acceptance Criteria:
- [x] `ChatApiService` accepts `category_list` and `money_source_list` as optional strings.
- [x] The request payload includes these lists in the `inputs` field if they are not empty.

**US-2: Direct ID Parsing**
As a developer, I want to use IDs provided by the AI directly in the record creation logic so that I can remove the "find and match" string logic.

Acceptance Criteria:
- [x] `ChatProvider` parsing logic uses `source_id` and `category_id` from the AI JSON response.
- [x] No more calls to `repository.getMoneySourceByName` are required during the happy-path parsing flow.

## Requirements
### Functional Requirements (MUST)

**FR-1: Service Formatting Helpers**
Add static methods to `ChatApiService` to format `List<MoneySource>` and `List<Category>` into `id-Name, id-Name` string formats.

**FR-2: Updated streamChat Interface**
Modify `ChatApiService.streamChat` to accept the formatted context strings and inject them into the API request's `inputs` map.

**FR-3: Provider Data Integration**
Update `ChatProvider` to hold a reference to `RecordProvider`. Ensure `sendMessage` fetches the latest sources and categories before calling the API.

**FR-4: Parser Refactor**
Rewrite the `onDone` JSON parsing logic in `ChatProvider`. It must now expect `source_id` and `category_id` in the JSON objects and use them to instantiate `Record` objects directly.

**FR-5: Graceful Fallbacks**
If the AI provides an invalid ID or fails to provide one, default to `source_id: 1` (Wallet) and `category_id: 1` (Uncategorized) to prevent crashes.

### Non-Functional Requirements
**NFR-1: Robustness**
The parser should not crash if the AI returns malformed JSON or unexpected ID types; it should log the error and skip the invalid record.

## Success Criteria
- [x] API requests to Dify now include `category_list` and `money_source_list` in the payload.
- [x] Records are successfully created in the database using IDs provided by the AI.
- [x] "Find and match" string logic is completely removed from `chat_provider.dart`.

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
| ---- | -------- | ---------- | ---------- |
| Prompt Mismatch | High | Medium | User will update server-side prompts manually to align with the new schema requirements. |
| Missing Data | Medium | Low | Use default IDs (1) if the AI returns null or invalid IDs. |

## Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5]
  nice_to_have: []
  nfr: [NFR-1]
scale: medium
discovery_mode: full
validation_status: pending
last_validated: null
