---
name: category-icons
description: Add a per-category emoji (AI-assigned for new categories, user-editable, generic fallback for existing) rendered everywhere a category is shown.
status: complete
priority: P1
scale: medium
created: 2026-05-24T17:50:25Z
updated: 2026-05-26T04:57:17Z
---

# PRD: category-icons

## Executive Summary

Today every category in WalletAI is name-only text ("Food & Drink", "Salary"), which makes the records list, the Categories tab, and chat suggestions slower to scan and visually flatter than the rest of the redesigned UI. This feature adds a single emoji per category, stored on the `Category` model. The server's AI picks an emoji whenever it proposes a new category in chat; users can change the emoji manually via the OS emoji keyboard in the category edit dialog; existing rows get a one-time generic 🏷️ on migration and seed categories get curated defaults (🍔 Food, 🚗 Transport, etc.). The emoji renders in the Categories tab, the record card subtitle, and the in-bubble suggestion banner — anywhere a category name appears.

## Problem Statement

The WalletAI Records list and Categories tab currently show categories as plain text only. When a user scrolls through 30+ records in a month, the text-only category column ("Food & Drink • Cash" / "Transport • Bank") forces them to read each row instead of pattern-matching by glyph — slow and tiring. The same flatness appears in the chat suggestion banner ("Should I create a new one called 'Commute'?") where there is no visual hint for what kind of category it is.

Workarounds today: none. The record card has a colored arrow icon (↗ for expense, ↙ for income) but that conveys direction, not category. Users learn category names by memory after weeks of use, but new users have no visual scaffolding.

Why now: the redesign-ui epic just landed new chat bubbles, suggestion banners, and pill buttons — the category area is the last text-only zone and looks notably less polished next to the new surfaces. Adding an emoji is the smallest change that closes the gap without committing to a full icon library or color system.

## Target Users

- **Daily logger** (the existing WalletAI user)
  - **Context:** Reviews the Records and Categories tabs multiple times per week; logs new transactions through the chat tab daily.
  - **Primary need:** Faster visual scanning of records and immediate recognition of categories in the AI's suggestions.
  - **Pain level:** Medium — current UX works but feels flat and is slower than necessary.

- **New user (first 7 days)**
  - **Context:** Just installed the app; doesn't yet have the muscle memory to recognize category names; relies on AI-detected categories for first transactions.
  - **Primary need:** Visual context for what each category represents without reading every label.
  - **Pain level:** High — text-only chips make onboarding feel utilitarian and unfinished.

## User Stories

**US-1: AI auto-suggests an emoji when proposing a new category**
As a daily logger, I want the AI to attach an emoji to any new category it suggests in chat, so that I can recognize the category visually the moment it's proposed without having to pick one myself.

Acceptance Criteria:
- [ ] The suggestion banner displays the proposed emoji inline with the suggestion text (e.g., "Should I create a new one called 🚌 'Commute'?").
- [ ] Confirming the suggestion persists the emoji on the new category.
- [ ] If the AI omits or returns an invalid emoji, the new category is created with the fallback 🏷️ and no error is shown to the user.

**US-2: Edit the emoji of any category**
As a daily logger, I want to change the emoji on any user-created category, so that I can correct an AI choice I disagree with or set the emoji on categories migrated from before this feature shipped.

Acceptance Criteria:
- [ ] The category edit dialog (parent and sub) shows an "Emoji" field next to the name field.
- [ ] Tapping the emoji field opens the OS emoji keyboard (via a Flutter emoji-picker package or a TextField with emoji input mode).
- [ ] Saving persists the new emoji to the categories table.
- [ ] Clearing the field saves the fallback 🏷️ — the category never renders without an emoji.

**US-3: See an emoji on every existing category after upgrade**
As a daily logger upgrading from a previous version, I want my existing categories to have a sensible emoji without any action from me, so that the new UI doesn't feel half-finished on launch.

Acceptance Criteria:
- [ ] The DB migration adds an `emoji` column with a default value.
- [ ] All seeded categories (Food, Transport, Salary, etc.) get curated emojis from a hard-coded map on first install.
- [ ] Any user-created category that existed before the migration gets the fallback 🏷️.
- [ ] No category renders without an emoji in the UI after upgrade.

**US-4: See the emoji wherever the category name appears**
As a daily logger scanning records, I want the category emoji to show up everywhere the category name shows up today, so that the visual cue is consistent across the app.

Acceptance Criteria:
- [ ] Categories tab list shows the emoji as the leading element of each row.
- [ ] Record card subtitle shows the emoji prefixed to the category name (e.g., "🍔 Food & Drink • Cash").
- [ ] Suggestion banner shows the emoji inline with the proposed category name.

## Requirements

### Functional Requirements (MUST)

**FR-1: Add `emoji` field to the Category model and schema**
The `Category` model gains a `String emoji` field (non-null, default `'🏷️'`). The SQLite schema gains an `emoji TEXT NOT NULL DEFAULT '🏷️'` column. `toMap`/`fromMap` and `copyWith` are updated to round-trip the field.

Scenario: New install
- GIVEN a fresh database
- WHEN the app seeds the default categories
- THEN each seeded category has the curated emoji from the seed map (e.g., Food → 🍔, Transport → 🚗)

Scenario: Existing install upgrade
- GIVEN a database created before this feature
- WHEN the app runs the schema migration
- THEN the `emoji` column is added with default `'🏷️'`
- AND every existing row has `emoji = '🏷️'` unless its `categoryId` matches a curated seed (in which case the curated emoji is backfilled)

**FR-2: Server returns emoji on `SuggestedCategory`**
The chatbot-flow-server's `SuggestedCategory` JSON gains an `emoji` field. The AI prompt instructs the model to return one emoji glyph that best represents the proposed category. Server validates and trims the AI's output to a single grapheme (max 8 codepoints to allow ZWJ sequences); invalid output is replaced with `'🏷️'` before returning.

Scenario: AI returns a valid emoji
- GIVEN the user logs an unrecognized transaction
- WHEN the server's category-detection prompt runs
- THEN the response includes `"emoji": "🚌"` (or similar single-grapheme emoji)

Scenario: AI returns invalid output
- GIVEN the AI returns `"emoji": "transport"` or `"emoji": ""` or omits the field
- WHEN the server validates the response
- THEN the response is rewritten to `"emoji": "🏷️"` before being sent to the client

**FR-3: Client parses and persists the suggested emoji**
The client `SuggestedCategory.fromJson` parses the new `emoji` field with a fallback to `'🏷️'`. When the user confirms a suggestion via the SuggestionBanner, the resolved/created `Category` is saved with the suggested emoji.

Scenario: User confirms an AI suggestion
- GIVEN the suggestion banner shows a proposed category with emoji 🚌
- WHEN the user taps "Confirm"
- THEN the resolveCategoryByNameOrCreate flow persists a new Category with `emoji = '🚌'`

**FR-4: Category edit dialog supports emoji input**
`category_form_dialog.dart` and `add_sub_category_dialog.dart` each gain a single emoji input — a tap-to-open emoji picker (using `emoji_picker_flutter` or equivalent). The current emoji is shown as the initial value; selecting a new emoji updates the field; save persists it. The default category (id=1) is not editable as today.

Scenario: User changes an emoji
- GIVEN a user opens the edit dialog for a category with `emoji = '🍔'`
- WHEN they tap the emoji field, pick 🍕 from the keyboard, and tap Save
- THEN the category is persisted with `emoji = '🍕'` and the Categories tab reflects the change immediately

Scenario: User clears the emoji field
- GIVEN a user clears the emoji input and saves
- WHEN the save handler validates the input
- THEN the empty value is replaced with `'🏷️'` and persisted (the category never has an empty emoji)

**FR-5: Render emoji in all category-display sites**
The emoji renders in three sites: (a) `CategoryWidget` (Categories tab list — leading element), (b) `RecordWidget` subtitle (prefixed to the category name), (c) `SuggestionBanner` (inline with the proposed category name in the italic suggestion text). The fork-icon mockup shape is not implemented — emoji renders as a plain `Text` widget at the appropriate font size.

Scenario: Categories tab
- GIVEN the user opens the Categories tab
- WHEN the list renders
- THEN each row shows the category emoji as the leading visual element (font size ~20)

Scenario: Records list
- GIVEN a record with `categoryId` pointing to "Food & Drink" (emoji 🍔)
- WHEN the record card renders
- THEN the subtitle reads "🍔 Food & Drink • Cash"

Scenario: Suggestion banner
- GIVEN a chat suggestion with category emoji 🚌 and name "Commute"
- WHEN the suggestion banner renders inside the AI message bubble
- THEN the italic suggestion text references the emoji alongside the category name

**FR-6: Migration backfill is idempotent and one-time**
The migration runs once at the schema version bump. It adds the `emoji` column with default `'🏷️'`, then runs a one-time UPDATE for each known seed `categoryId` (1..N) to backfill the curated emoji. Subsequent app launches do not re-run this backfill.

Scenario: Migration runs twice (developer rebuild scenario)
- GIVEN the migration has already run
- WHEN the app launches again
- THEN no UPDATEs are issued and no category emojis are overwritten

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: AI suggests an emoji when a user renames a category**
When a user renames an existing category in the edit dialog, the dialog could offer a one-tap "suggest emoji" button that calls the server to propose a fresh emoji based on the new name. Deferred because: the user can already pick from the OS keyboard, and adding a round-trip call to the edit dialog complicates the flow for a marginal benefit.

### Non-Functional Requirements

**NFR-1: Validation and fallback**
Both server and client treat the emoji field as best-effort. Server validates AI output (single grapheme, max 8 codepoints, must contain at least one codepoint in the Unicode emoji range — if not, fallback to 🏷️). Client treats any missing/null/empty value as 🏷️. The app must never render an empty space, a question mark glyph (`�`), or an empty string in place of a category emoji.

**NFR-2: No performance regression on the Categories or Records tab**
Adding the emoji column and rendering must not increase first-frame time by more than 5ms on the Records tab (which paginates) or the Categories tab. Emoji is rendered as a `Text` widget — no asset loading, no async work.

**NFR-3: Cross-platform rendering parity**
Emoji must render correctly on both iOS (Apple Color Emoji) and Android (Noto Color Emoji / vendor variant). Visual differences between platforms are acceptable; a missing-glyph "tofu" box (`☐`) is not. The fallback 🏷️ is the U+1F3F7 LABEL emoji, supported in Unicode 7+ which all target platforms render.

## Success Criteria

- **All categories render an emoji within 1 launch of the upgrade.** Measured: post-migration, query `SELECT COUNT(*) FROM categories WHERE emoji IS NULL OR emoji = ''` returns 0. Verified once via a dev-mode assertion in `init` flow.
- **AI-suggested emoji is accepted by users in ≥80% of confirmations.** Measured: track confirmation rate where the user does not subsequently edit the category emoji within 24 hours of confirming the suggestion. Sample reviewed manually after 100 confirmations.
- **No reported "missing icon" / "broken emoji" issues from beta users.** Measured: zero qualifying issues in 14 days post-launch from beta feedback channel.
- **Categories tab and Records tab first-frame render time does not regress beyond 5ms.** Measured: dev-mode profiler trace before/after, captured during QA pass.

## Risks & Mitigations

| Risk                                                                                 | Severity | Likelihood | Mitigation                                                                                                                                                            |
| ------------------------------------------------------------------------------------ | -------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AI returns invalid output (text, multi-emoji, missing field) and breaks the UI       | High     | High       | Server-side validation strips to one grapheme + fallback to 🏷️; client also defensively coalesces null/empty/invalid to 🏷️.                                          |
| Emoji renders differently on iOS vs Android, breaking visual consistency             | Low      | High       | Accept platform-native rendering as a design constraint (consistent with how every other modern app treats emoji). Document this in the PRD.                          |
| Migration backfill runs on a corrupted/partial DB and overwrites custom user emojis  | Medium   | Low        | Backfill UPDATE only applies to rows where `emoji = '🏷️'` (i.e., never overwrites a non-default value). One-time gated by schema version bump.                       |
| `emoji_picker_flutter` package (or chosen equivalent) is unmaintained / heavy        | Medium   | Medium     | First try a plain `TextField` with `keyboardType: TextInputType.text` and rely on OS emoji keyboard; only add a picker package if UX testing shows the tap is unclear. |
| Server prompt change causes regressions in the existing `name`/`type` suggestion     | Medium   | Medium     | Add the emoji as an additive JSON field; do not change the existing fields' contract. Verify via existing suggestion tests on the server.                             |

## Constraints & Assumptions

**Constraints:**
- Must work with the existing `Category` model and `categories` SQLite table — no migration to a new table.
- Must not require a new asset bundle (no SVG / PNG icon packs).
- Server change is in scope but limited to the WalletAI project in `../chatbot-flow-server/` (per CLAUDE.md).
- Flutter + provider + repository patterns already in use must be preserved (per `project_context/architecture.md`).

**Assumptions:**
- *AI can reliably pick a representative single emoji for arbitrary category names.* If wrong: many new categories get the fallback 🏷️ and users edit manually — degraded UX but not broken.
- *OS emoji keyboards are accessible enough that users don't need an in-app emoji picker.* If wrong: we add `emoji_picker_flutter` in a follow-up PR.
- *Cross-platform emoji rendering variation is acceptable.* If wrong: we'd need to ship a custom emoji font (e.g., Twemoji) — out of scope for this PRD.
- *The existing curated seed-category set is the right starting point for default emojis.* If wrong: easy to adjust the seed map in a follow-up.

## Out of Scope

- **Custom Material icon library** — not building a `Map<String, IconData>` allowlist; emoji-only.
- **Per-category background color** — categories stay visually distinguished by emoji alone; no color picker.
- **User-uploaded image** as category icon — not supported.
- **In-app emoji picker grid** (custom UI beyond the OS keyboard) — relying on OS keyboard first; defer custom picker unless UX testing demands it.
- **Retroactive AI re-classification** of existing user-set emojis — once the user sets an emoji, AI never overwrites it.
- **Emoji on `MoneySource`, `Record`, or other models** — categories only. (Sources, transfers, etc. keep their existing visuals.)
- **Animated / Lottie / dynamic icons** — emoji is a static glyph.

## Dependencies

- **`chatbot-flow-server` (WalletAI prompt)** — Owner: same team — Status: pending. The category-detection prompt and `SuggestedCategory` schema must add the `emoji` field and validation.
- **`emoji_picker_flutter` package (optional)** — Owner: pub.dev — Status: pending. Only required if MVP TextField+OS keyboard tests poorly; otherwise no new dependency.
- **`redesign-ui` epic** — Owner: same team — Status: completed (recently merged). This PRD assumes the redesigned `RecordWidget`, `SuggestionBanner`, and `CategoryWidget` are the integration surfaces.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5, FR-6]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2, NFR-3]
scale: medium
discovery_mode: full
validation_status: warning
last_validated: 2026-05-25T02:19:31Z
