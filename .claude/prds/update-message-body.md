---
name: update-message-body
description: Enhance chat API requests with category/source context and simplify AI record parsing.
status: backlog
priority: P1
scale: medium
created: 2026-03-19T06:30:00Z
updated: null
---

# PRD: update-message-body

## Executive Summary
This epic optimizes the communication between the AI assistant and the app by providing the AI with clear context regarding available money sources and record categories. By sending these lists (formatted as `id-Name`) in the `streamChat` request, we enable the AI to return specific IDs directly in its response. This allows us to remove fragile string-matching logic in the app's parser, leading to more reliable record creation and better data integrity.

## Problem Statement
The current `ChatProvider` uses a "find and match" strategy to link AI-generated record names to database IDs. This is error-prone, especially with similar names or typo variations. Additionally, the AI has no knowledge of the app's internal categories, forcing it to default to "Uncategorized" or return plain text strings that require further manual mapping.

## Target Users
| Role | Context | Primary Need | Pain Level |
| ---- | ------- | ------------ | ---------- |
| AI Agent | Generating financial records | Needs to know the valid IDs for sources and categories to avoid "guessing" names. | High |
| Developer | Maintaining parsing logic | Wants to remove complex string-matching code in favor of direct ID mapping. | Medium |

## User Stories
**US-1: Contextual Chat Requests**
As an AI Agent, I want to receive a list of available money sources and categories in every chat request so that I can provide structured data that matches the app's schema.

Acceptance Criteria:
- [ ] `ChatApiService` accepts `category_list` and `money_source_list` as optional strings.
- [ ] The request payload includes these lists in the `inputs` field if they are not empty.

**US-2: Direct ID Parsing**
As a developer, I want to use IDs provided by the AI directly in the record creation logic so that I can remove the "find and match" string logic.

Acceptance Criteria:
- [ ] `ChatProvider` parsing logic uses `source_id` and `category_id` from the AI JSON response.
- [ ] No more calls to `repository.getMoneySourceByName` are required during the happy-path parsing flow.

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

### Functional Requirements (NICE-TO-HAVE)
- N/A

### Non-Functional Requirements
**NFR-1: Robustness**
The parser should not crash if the AI returns malformed JSON or unexpected ID types; it should log the error and skip the invalid record.

## Success Criteria
- [ ] API requests to Dify now include `category_list` and `money_source_list` in the payload.
- [ ] Records are successfully created in the database using IDs provided by the AI.
- [ ] "Find and match" string logic is completely removed from `chat_provider.dart`.

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
| ---- | -------- | ---------- | ---------- |
| Prompt Mismatch | High | Medium | User will update server-side prompts manually to align with the new schema requirements. |
| Missing Data | Medium | Low | Use default IDs (1) if the AI returns null or invalid IDs. |

## Constraints & Assumptions
- **Constraints:** Must use the `id-Name` string format for AI prompts as requested.
- **Assumptions:** The user will update the Dify backend prompts to correctly utilize the provided ID context.

## Out of Scope
- Creating a UI for the user to manage the context strings.
- Updating server-side prompts (User-handled).

## Dependencies
- `RecordProvider` (must be accessible to `ChatProvider`).
- `Category` model (added in previous epic).

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5]
  nice_to_have: []
  nfr: [NFR-1]
scale: medium
discovery_mode: full
validation_status: pending
last_validated: null
