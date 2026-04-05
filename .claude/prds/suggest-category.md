---
name: suggest-category
description: Show AI-suggested new category inline in chat when a record can't be classified; let user confirm to create it and re-assign the record.
status: backlog
priority: P1
scale: medium
created: 2026-04-05T15:45:12Z
updated: 2026-04-05T16:07:08Z
---

# PRD: suggest-category

## Executive Summary

When a user logs an expense the AI cannot match to an existing category (e.g., "Netflix 50k"), the server already returns a `suggested_category` object (`name`, `type`, `parent_id`, `message`) alongside `category_id: -1`. The Flutter client currently ignores this object entirely — the record is silently saved as Uncategorized and the AI's suggestion is discarded. This feature closes that gap: parse the suggestion per-record, render an inline suggestion banner beneath each unclassified record in the chat, and let the user confirm (creates the category and re-assigns the record) or cancel (keeps it Uncategorized). No server changes required.

## Problem Statement

A user types "50k tài khoản Netflix" and the AI correctly identifies it as an expense that doesn't fit any default category. The server does the hard work — it synthesizes a name ("Streaming"), a type ("expense"), a parent ID (top-level, `-1`), and a friendly invitation message — and encodes all of this in the JSON response. The client splits on `--//--`, extracts the record, saves it with `categoryId: -1`, and discards the `suggested_category` field entirely.

The user sees a confirmation like "Recorded your Netflix subscription!" but the record appears as "Unknown" or "Uncategorized" in their list. If they want it categorized, they must: (1) open the Categories tab, (2) manually create a "Streaming" category, (3) return to Records, (4) edit the record. That is four steps for something the AI already solved in one.

This happens every time the user spends on anything outside the default 8 categories — streaming, pets, education, hobbies — which are exactly the categories power users care most about.

## Target Users

**Returning Power User — Specialty Spender**
- Who: Has custom expenses that recur outside the 8 default categories (e.g., subscriptions, courses, pet care)
- Context: Logs expense in chat, sees "Uncategorized" appear repeatedly
- Primary need: Classify unusual expenses in the same conversational flow, not in a separate settings screen
- Pain level: High — every uncategorized record requires a 4-step out-of-flow detour

**Occasional User — Curious About Categories**
- Who: Uses mostly default categories but occasionally hits something new
- Context: The AI suggests a name they hadn't thought of (e.g., "Freelance" sub of Salary)
- Primary need: Accept the AI's reasonable suggestion without forming opinions about it
- Pain level: Medium — infrequent but delightful when it works

## User Stories

**US-1: See AI suggestion for unclassified record**
As a user who logged an expense the AI couldn't classify, I want to see the AI's category suggestion inline in the chat, so that I can act on it without leaving the conversation.

Acceptance Criteria:
- [ ] After the stream completes, if a record has `category_id: -1` and a non-null `suggested_category`, a suggestion banner appears below that record card
- [ ] The banner shows the AI's `message` field (e.g., "I couldn't find a category for Streaming. Want to create one?")
- [ ] The banner shows the suggested category name and type
- [ ] Records with a matched category (not -1) show no banner — UI is unchanged

**US-2: Confirm suggestion to create category and re-classify**
As a Returning Power User, I want to tap Confirm on a suggestion so that the new category is created and my record is reclassified immediately.

Acceptance Criteria:
- [ ] Tapping Confirm calls `recordProvider.addCategory(Category(name, type, parentId))` with data from `suggested_category`
- [ ] On success, the record's `categoryId` is updated in the DB via `recordProvider.updateRecord`
- [ ] The chat UI reflects the updated category name (banner disappears, record shows correct category)
- [ ] If the suggested category name already exists, it reuses the existing category rather than creating a duplicate

**US-3: Cancel suggestion**
As a Returning Power User, I want to tap Cancel to dismiss the suggestion and leave the record as Uncategorized.

Acceptance Criteria:
- [ ] Tapping Cancel removes the suggestion banner from the UI
- [ ] The record is not modified in the DB — it stays with `categoryId: -1` (Uncategorized)
- [ ] No category is created

**US-4: Handle multiple records with suggestions in one message**
As a Returning Power User who logged multiple expenses in one message, I want each unclassified record to show its own suggestion independently.

Acceptance Criteria:
- [ ] Each record's suggestion is independently confirmable/cancelable
- [ ] Confirming one suggestion does not affect other records in the same message
- [ ] If two records suggest the same category name, confirming the first re-uses the created category for the second (no duplicate)

**US-5: Accept a sub-category suggestion from the AI**
As an Occasional User, I want the AI to suggest a sub-category (e.g., "Freelance" under Salary) for an income record I logged, so that I can accept a classification I wouldn't have thought of myself.

Acceptance Criteria:
- [ ] When `suggested_category.parent_id` refers to an existing parent category, the banner identifies it as a sub-category (e.g., "Add 'Freelance' under Salary?")
- [ ] Confirming creates the sub-category with the correct `parentId` and re-assigns the record

## Requirements

### Functional Requirements (MUST)

**FR-1: Parse `suggested_category` from record JSON**
The record JSON array may include a `suggested_category` object per item. When `category_id` is `"-1"` and `suggested_category` is non-null, extract it and store it as a transient field on the `Record` model. This field is NOT persisted to SQLite.

Scenario: Record with suggestion
- GIVEN the server returns `[{"source_id": "1", "amount": 50000, "category_id": "-1", "suggested_category": {"name": "Streaming", "type": "expense", "parent_id": -1, "message": "Want to create a Streaming category?"}, ...}]`
- WHEN `ChatProvider._handleStream` parses the JSON on stream completion
- THEN the saved `Record` has `categoryId: -1` in the DB and carries the `suggested_category` data as a transient in-memory field

Scenario: Record without suggestion (normal path)
- GIVEN `suggested_category` is `null` and `category_id` is a valid ID
- WHEN parsed
- THEN record is saved normally; no suggestion state; no regression to existing behavior

Scenario: Malformed `suggested_category`
- GIVEN the field is present but missing required sub-fields (e.g., no `name`)
- WHEN parsed
- THEN suggestion is silently ignored; record saved as-is; no crash

**FR-2: Add transient `SuggestedCategory` to `Record` model**
Introduce a `SuggestedCategory` data class (`name: String`, `type: String`, `parentId: int`, `message: String`) and add a nullable `suggestedCategory` field to `Record`. The field must be excluded from `toMap()`/`fromMap()` so it is never written to or read from SQLite.

Scenario: Model roundtrip
- GIVEN a `Record` with `suggestedCategory != null`
- WHEN `toMap()` is called (for DB insert)
- THEN the resulting map does NOT contain any `suggested_category` key
- AND reading the record back from DB via `fromMap()` returns `suggestedCategory: null`

**FR-3: Render suggestion banner in chat message widget**
The chat message widget (record card area) must display a suggestion banner below each record that has a non-null `suggestedCategory`. The banner is a sibling widget rendered inside the record list builder within the chat message widget (e.g., `chat_message_widget.dart`), immediately after the record card — not nested inside the card itself. The banner shows:
- The AI's `message` text
- The suggested category name and type badge
- A Confirm button and a Cancel button

The banner is only shown while the suggestion is active (not after confirm or cancel).

Scenario: Suggestion visible
- GIVEN a chat message containing a record with `suggestedCategory != null`
- WHEN the user views the chat
- THEN the suggestion banner appears beneath that record card
- AND other records in the same message without suggestions show no banner

Scenario: Stream in progress
- GIVEN the assistant message is still streaming
- THEN no suggestion banner is shown (suggestion state is only set after stream completes)

**FR-4: Confirm creates category and re-assigns record**
Tapping Confirm triggers the full create-and-reclassify sequence:
1. Check if a category with the same `name` already exists in `RecordProvider.categories`. If yes, use its `categoryId`. If no, call `recordProvider.addCategory(Category(name, type, parentId))`.
2. Retrieve the new `categoryId`.
3. Call `recordProvider.updateRecord(record.copyWith(categoryId: newCategoryId))`.
4. Call `chatProvider.updateMessageRecord(messageId, updatedRecord)` to update in-memory state.
5. Clear the `suggestedCategory` from the in-memory record so the banner disappears.

Scenario: New top-level category
- GIVEN user confirms suggestion `{name: "Streaming", type: "expense", parent_id: -1}`
- WHEN confirmed
- THEN `Category(name: "Streaming", type: "expense", parentId: -1)` is created
- AND the record is updated with the new `categoryId`
- AND the suggestion banner disappears, replaced by the category name "Streaming"

Scenario: New sub-category
- GIVEN suggestion `{name: "Netflix", type: "expense", parent_id: 4}` (parent: Entertainment)
- WHEN confirmed
- THEN `Category(name: "Netflix", type: "expense", parentId: 4)` is created as a sub-category
- AND record is updated

Scenario: Category name already exists
- GIVEN "Streaming" already exists with `categoryId: 12`
- WHEN user confirms suggestion with `name: "Streaming"`
- THEN no new category is created; record is updated with `categoryId: 12`

**FR-5: Cancel clears suggestion banner without modifying data**
Tapping Cancel removes the suggestion banner from the UI by clearing the `suggestedCategory` transient field from the in-memory record. No DB write occurs. No category is created.

Scenario: Cancel
- GIVEN suggestion banner is visible
- WHEN user taps Cancel
- THEN banner disappears; record in DB is unchanged (`categoryId: -1`); no category created

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Editable suggested name**
Allow the user to edit the suggested category name before confirming. Deferred — the AI's name is almost always usable and adding a text field adds friction and scope to the widget layer.

Scenario: Edit before confirm
- GIVEN the suggestion banner is visible with name "Streaming"
- WHEN user taps an edit icon on the banner
- THEN an inline text field appears pre-filled with "Streaming"
- AND user can modify the name before tapping Confirm

### Non-Functional Requirements

**NFR-1: No regression on existing record parsing**
The existing record JSON parsing path (records with valid `category_id`) must produce identical output before and after this change. Zero test regressions.

**NFR-2: No crash on malformed or absent `suggested_category`**
Any parse failure of the `suggested_category` field must be silently swallowed. App continues normally; suggestion is simply absent.
Threshold: 0 crashes from malformed JSON; verified by unit test with bad/missing fields.

**NFR-3: Confirm/cancel actions are idempotent**
Tapping Confirm or Cancel twice (e.g., double-tap) must not create duplicate categories or fire duplicate DB writes.
Threshold: At most 1 category created per suggestion; at most 1 record update per confirm.

## Success Criteria

- **Functional coverage:** All records with `category_id: -1` + `suggested_category` in chat show a suggestion banner — verified by QA with a message that triggers unclassified category
- **Create accuracy:** Confirm creates exactly one category and updates the record — verified by checking DB before/after in unit test
- **No regression:** Existing record parsing tests pass unchanged — 0 test failures
- **Graceful failure:** Unit test injecting malformed `suggested_category` JSON does not crash — 0 crashes
- **Duplicate guard:** Confirming two suggestions with the same name in one message creates exactly 1 category — verified by QA
- **Cancel purity:** Tapping Cancel leaves the record's `categoryId` unchanged in the DB and creates no new category — verified by unit test asserting `recordProvider.updateRecord` and `addCategory` were NOT called

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| `addCategory` returns void (no new ID) — can't reclassify record | High | High | After `addCategory`, query `recordProvider.categories` to find the newly created category by name; use its `categoryId` |
| Double-tap Confirm fires two category creates | Med | Med | Disable Confirm button immediately on first tap; re-enable only on error |
| `suggestedCategory` stored on `Record` causes issues in existing code paths that copy/serialize records | Med | Low | Add field after `toMap()`/`fromMap()` and ensure all `copyWith` implementations pass it through |
| Multiple records in one message suggest the same category name — two confirms would try to create the same category | Med | Med | Implement name-exists check (FR-4) before creating; first confirm creates, second confirm reuses |
| `parent_id` from server references a `categoryId` that doesn't exist locally (schema drift) | Low | Low | Validate `parent_id` exists in `RecordProvider.categories` before create; fall back to `parent_id: -1` (top-level) if invalid |

## Constraints & Assumptions

**Constraints:**
- No server changes — `suggested_category` is already in the response payload
- Must use `RecordProvider.addCategory` and `updateRecord` — no direct repository access from ChatProvider or UI
- `Category` model allows at most 2 levels (parent + sub); `parent_id` from server is trusted to respect this
- `SuggestedCategory` must NOT be persisted to SQLite — transient in-memory only

**Assumptions:**
- `addCategory` does not return the new `categoryId`; we find it by querying `recordProvider.categories` by name after create. If wrong (e.g., name collision race): the lookup may find a pre-existing category with the same name — acceptable, per FR-4 duplicate guard.
- `suggested_category` only appears on records with `category_id: "-1"`. If wrong (appears on already-classified records): the banner would show unnecessarily — guard by checking `categoryId == -1` before rendering.
- `parent_id: -1` in the suggestion means top-level category. If wrong: sub-category would be created at top level — acceptable degradation.
- The suggestion data is session-only. After the app restarts, records with `categoryId: -1` show no banner (suggestion was transient). If wrong expectation: user may be surprised — acceptable; the record remains accessible and editable from the Records tab.

## Out of Scope

- **Editing suggested name** — deferred as NTH-1; adds widget complexity for marginal gain
- **Suggestion in Records tab** — only chat flow; records with `categoryId: -1` are already accessible via the category management flow
- **Undo after confirm** — deleting a just-created category is already possible via the Categories tab
- **Suggestion from non-chat AI flows** — only the normal conversation response produces `suggested_category`
- **Persisting suggestion state across restarts** — session only; no storage changes

## Dependencies

- `RecordProvider.addCategory(Category)` — exists in `lib/providers/record_provider.dart:283` — **resolved**
- `RecordProvider.updateRecord(Record)` — exists in `lib/providers/record_provider.dart` — **resolved**
- `ChatProvider.updateMessageRecord(messageId, Record)` — exists in `lib/providers/chat_provider.dart:265` — **resolved**
- `Category` model with `parentId` support — exists in `lib/models/category.dart` — **resolved**
- `add-sub-category` epic (PRD: backlog) — provides the `parentId` DB schema used by sub-category creation path — **dependency**: this PRD assumes `parentId` column exists; if `add-sub-category` is not yet shipped, sub-category suggestions (`parent_id != -1`) will still work correctly (the column exists already per current schema)

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2, NFR-3]
scale: medium
discovery_mode: express
validation_status: warning
last_validated: 2026-04-05T16:12:39Z
