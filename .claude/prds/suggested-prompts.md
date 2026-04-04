---
name: suggested-prompts
description: Parse suggestedPrompts from greeting JSON and display as interactive 3-step chip flow above chat input for returning users
status: complete
priority: P1
scale: medium
created: 2026-04-03T03:55:18Z
updated: 2026-04-04T12:41:45Z
---

# PRD: suggested-prompts

## Executive Summary

Wally AI's server already generates personalized `suggestedPrompts` in the greeting JSON for returning users who have a stored spending pattern, but the Flutter client silently ignores this data — users must type every expense from scratch every session. This feature parses the `suggestedPrompts` payload, stores it in `ChatProvider`, and renders it as an interactive horizontal chip bar above the chat input. Users follow a deliberate 3-step flow: tap a prompt to pre-fill the input, optionally tap an action chip to append an amount, then edit freely and send. Sending removes that prompt from the list, keeping the bar focused on unused suggestions. New users (no pattern) are completely unaffected.

## Problem Statement

A returning user opens Wally AI and receives a personalized greeting: *"Welcome back! You've been spending on Bánh mì twice a week."* The server has already done the hard work of analyzing their pattern and encoding a suggestion like `{"suggestedPrompts": [{"prompt": "Bánh mì", "actions": ["15k", "20k"]}]}` into the response. The client splits on `--//--`, finds no record array, and discards the JSON entirely.

The user sees a warm greeting and a blank input. To log their usual expense, they type it out character by character — the same as day one. This happens every session, for every recurring expense. The AI's pattern analysis delivers zero UX value at the point of logging. The workaround is manual typing, which is the exact problem Wally AI exists to reduce.

*New users (first session, no stored pattern) receive a plain greeting with no JSON payload — the server never generates `suggestedPrompts` without pattern data. This feature is completely invisible to them; their experience is unchanged.*

## Target Users

**Returning User — Daily Logger**
- Who: Has used the app for several days/weeks, has a stored `long_term_user_pattern`
- Context: Opens app 1-2x/day to quickly log recurring expenses (coffee, lunch, transport)
- Primary need: Log familiar expenses in under 5 seconds with minimal typing
- Pain level: High — types the same thing every day with zero shortcut

**Returning User — Occasional Logger**
- Who: Has a stored pattern but opens the app a few times a week, not daily
- Context: Less muscle-memory for what they normally spend; prompts serve as a reminder of their own habits
- Primary need: Be reminded of their recurring expenses without having to recall them
- Pain level: Medium — less repetitive friction than daily logger, but prompts provide discovery value

## User Stories

**US-1: See contextual prompt chips after greeting**
As a returning user, I want to see my AI-suggested expense prompts above the chat input after the greeting loads, so that I can identify a quick shortcut without scrolling or thinking.

Acceptance Criteria:
- [ ] After the greeting stream completes, a horizontal scrollable chip row appears above the chat input
- [ ] Each chip displays the `prompt` text (e.g., "Bánh mì")
- [ ] The chip row is only rendered when `suggestedPrompts` is non-empty
- [ ] New users (greeting with no `suggestedPrompts` JSON) see no chip row — UI is identical to current state

**US-2: Tap a prompt to pre-fill input and reveal amount actions**
As a returning user, I want to tap a prompt chip so that the chat input is pre-filled with that expense name and I can pick a suggested amount.

Acceptance Criteria:
- [ ] Tapping a prompt chip clears the current input content and sets it to the prompt text
- [ ] The text field receives focus after tap
- [ ] The prompt chip row is replaced by that prompt's action chips (e.g., "15k", "20k")
- [ ] If the prompt has no actions (`actions: []`), no action row appears — input is pre-filled and ready

**US-3: Tap an action to append amount and prepare to send**
As a returning user, I want to tap an amount chip so that it is appended to my pre-filled input, leaving me free to adjust and send.

Acceptance Criteria:
- [ ] Tapping an action chip appends `" {action}"` to the current input (e.g., "Bánh mì" → "Bánh mì 15k")
- [ ] The action chip row disappears immediately after tap
- [ ] The user can freely edit the resulting input text before sending

**US-4: Send removes the used prompt from the list**
As a returning user, I want the prompt I just used to disappear after I send, so that remaining chips are only for expenses I haven't logged yet this session.

Acceptance Criteria:
- [ ] Sending a message while a prompt is selected (regardless of whether an action was tapped) removes that prompt from the list
- [ ] The chip bar updates to show only remaining prompts
- [ ] If no prompt is selected when sending (free-text message), the prompt list is unchanged
- [ ] If the last prompt is consumed, the chip bar disappears entirely

## Requirements

### Functional Requirements (MUST)

**FR-1: Parse `suggestedPrompts` object from greeting JSON**
The greeting response may contain `{"suggestedPrompts": [{...}]}` after the `--//--` delimiter. This is a JSON object (not an array), and must be parsed into a `List<SuggestedPrompt>` as a separate branch from the existing record array parsing. Skipping this breaks the entire feature.

Scenario: Greeting with suggestedPrompts
- GIVEN the server returns `greeting_text--//--{"suggestedPrompts": [{"prompt": "Bánh mì", "actions": ["15k", "20k"]}]}`
- WHEN the greeting stream completes and JSON is decoded
- THEN `ChatProvider.suggestedPrompts` contains one entry with `prompt: "Bánh mì"` and `actions: ["15k", "20k"]`

Scenario: Greeting without JSON (new user)
- GIVEN the server returns a plain text greeting with no `--//--` delimiter
- WHEN the stream completes
- THEN `ChatProvider.suggestedPrompts` remains empty, no chip bar is rendered

Scenario: Greeting with record array (existing path)
- GIVEN the JSON part is a list `[{record...}]`
- WHEN the stream completes
- THEN records are parsed as before; `suggestedPrompts` remains empty; no regression

**FR-2: Display prompt chip bar above chat input**
Render a horizontally scrollable row of chips between the message list and the text input field. The bar is only present when `ChatProvider.suggestedPrompts` is non-empty. No layout shift — the bar appears in the same frame as the final `notifyListeners()`.

Scenario: Prompts available
- GIVEN `ChatProvider.suggestedPrompts` has 2 entries after greeting
- WHEN the chat tab is rendered
- THEN a horizontal chip row appears above the input with 2 chips; the message list's bottom padding increases to prevent any chat bubble from being occluded by the chip bar

Scenario: No prompts
- GIVEN `ChatProvider.suggestedPrompts` is empty
- WHEN the chat tab is rendered
- THEN no chip row is present; the input sits at the bottom as before

**FR-3: Prompt tap pre-fills input and replaces prompt chips with action chips**
Tapping a prompt chip sets provider state to mark it as active, clears the text input, inserts the prompt text, and **replaces** the entire chip bar with that prompt's action chips. The prompt list and action list are mutually exclusive — they are never displayed at the same time. Only one chip row is ever visible: either the prompt list or the action list for the currently active prompt.

*Forward paths while actions are showing:* the user may tap an action (FR-4), edit input freely, or send (FR-5). There is no re-selection path — prompt chips are hidden and cannot be interacted with. The only way to reach remaining prompts is after sending (which removes the active prompt and restores the remaining prompt list).

Scenario: Prompt with actions
- GIVEN chip bar shows prompt chips ["Bánh mì", "Phở"] and user taps "Bánh mì"
- WHEN tap is processed
- THEN input text is set to "Bánh mì", input gains focus, the prompt chip row is gone and replaced entirely by action chips ["15k", "20k"]; no prompt chips are visible

Scenario: Prompt with no actions
- GIVEN a prompt has `actions: []`
- WHEN user taps that chip
- THEN input text is set to the prompt text, chip bar disappears entirely (no actions to show), input is ready to send

**FR-4: Action tap appends to input and hides action chips**
Tapping an action chip appends its text to the current input with a space separator and immediately hides the action row. The user then edits and sends freely.

Scenario: Action tap
- GIVEN input contains "Bánh mì" and action chips show ["15k", "20k"]
- WHEN user taps "15k"
- THEN input becomes "Bánh mì 15k", action chip row is hidden, user may edit further

**FR-5: Send removes active prompt from list**
When the user sends a message and a prompt is currently active (selected), remove it from `ChatProvider.suggestedPrompts` and notify listeners. If no prompt is active, the list is unchanged.

Scenario: Send with active prompt
- GIVEN suggestedPrompts = ["Bánh mì", "Cà phê"], "Bánh mì" is active (action chips may or may not be showing)
- WHEN user sends the message
- THEN suggestedPrompts = ["Cà phê"], action chips are cleared, chip bar reverts to showing remaining prompt chips ["Cà phê"]; "Bánh mì" is gone for the session

Scenario: Send without active prompt (free text)
- GIVEN suggestedPrompts = ["Bánh mì", "Cà phê"], no prompt is selected
- WHEN user types "Grab 25k" and sends
- THEN suggestedPrompts unchanged, chip bar still shows both chips

Scenario: Last prompt consumed
- GIVEN suggestedPrompts = ["Bánh mì"], it is active
- WHEN user sends
- THEN suggestedPrompts = [], chip bar disappears entirely

Scenario: Input manually cleared by user
- GIVEN "Bánh mì" is the active prompt and input contains "Bánh mì 15k"
- WHEN user selects all text and deletes it, leaving input empty
- THEN active prompt selection is unchanged; if user sends the empty message, "Bánh mì" is still removed from the list (active state persists through input edits, cleared only by sendMessage)

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Manual dismiss of chip bar**
User can close the entire suggested prompt area via an ✕ button if they don't want the suggestions this session.

Deferred: Not essential for core value. Users can ignore the chip bar. Low friction even without dismiss. Add only if user feedback indicates the bar feels intrusive.

Scenario: User dismisses chip bar
- GIVEN chip bar is visible with 2 prompts
- WHEN user taps dismiss button
- THEN chip bar hides for the remainder of the session; prompts are discarded

### Non-Functional Requirements

**NFR-1: No layout shift on chip bar appearance**
The chip bar must render in the same frame as the final `notifyListeners()` after greeting stream completes. No delayed `setState` or async render that causes the message list to jump.
Threshold: 0 visible layout shifts measured on a standard device; chip bar appears atomically with the greeting message.

**NFR-2: Chip bar does not overlap message content**
The message list's bottom padding must account for chip bar height when visible. No chat bubble may be obscured by the chip row.
Threshold: When chip bar is visible, the message list's bottom inset is at least chip bar height (~48px) + input bar height (~56px) + safe area padding; no chat bubble is partially occluded at any scroll position, verified by QA scrolling to the bottom of the message list.

**NFR-3: Graceful parse failure**
If the server returns malformed or unexpected `suggestedPrompts` JSON, parsing must fail silently without crashing the app or breaking the greeting display.
Threshold: 0 crashes on malformed JSON; chat continues normally; `suggestedPrompts` remains empty.

## Success Criteria

- **Functional coverage:** All returning users who receive `suggestedPrompts` in greeting JSON see the chip bar — verifiable by QA: trigger greeting with stored pattern, confirm chips appear. Target: 100% of qualifying sessions.
- **No regression:** Existing record-parsing path produces identical output before and after — confirmed by running existing `ChatProvider` unit tests. Target: 0 test failures.
- **New user parity:** New user greeting flow shows no chip bar, no layout change — verified by QA with cleared storage. Target: UI identical to pre-feature state.
- **Parse resilience:** Greeting with malformed JSON partial payload does not crash — verified by unit test injecting bad JSON. Target: 0 crashes.
- **Logging speed:** A returning user can complete prompt → action → send flow in ≤5 seconds from greeting load — verifiable by QA stopwatch test on 3 scenarios (with actions, without actions, with manual amount edit).

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| State stored in widget (setState) instead of ChatProvider, lost on rebuild | High | Med | Enforce in PR review: `_suggestedPrompts`, `_activePromptIndex`, `_showingActions` must live in `ChatProvider` |
| JSON object vs record array ambiguity in parser causes wrong branch | High | Med | Detect by checking for `suggestedPrompts` key first; only fall back to array parse if key absent |
| Server schema change (adds field, renames key) silently breaks feature | Med | Low | Parse defensively with try-catch; log warning; treat parse failure as empty prompts |
| Chip bar height causes bottom overflow on small screens | Med | Med | Use `SingleChildScrollView(scrollDirection: Axis.horizontal)` with fixed height constraint |
| Active prompt not cleared after send, causing stale removal on next send | Med | Low | Reset `_activePromptIndex` to null and `_showingActions` to false inside `sendMessage()` after removal |

## Constraints & Assumptions

**Constraints:**
- Must use existing `--//--` delimiter and `ChatConfig` constants — no server changes required or allowed
- Must not modify the existing record JSON parsing branch — additive only
- State management must follow Provider pattern (no local widget state for prompt list or selection)
- `TextEditingController` stays widget-owned — `ChatProvider` exposes callbacks, widget applies changes

**Assumptions:**
- Server always encodes `suggestedPrompts` as a JSON object `{"suggestedPrompts": [...]}`, not a top-level array. If wrong: object detection branch won't match → chips silently absent.
- `actions` is always `List<String>`. If wrong: type cast will throw at parse time → caught by try-catch, prompts = empty.
- `suggestedPrompts` only appears in the initial greeting message. If wrong: subsequent messages with this key would be silently ignored (acceptable for now).
- User's pattern quality is sufficient for the server to generate meaningful suggestions. If wrong: chip bar either doesn't appear (no JSON) or shows low-relevance prompts (user ignores them) — both acceptable degradations.

## Out of Scope

- **Flat chips (prompt + amount combined)** — User needs to edit amounts frequently; pre-combining forces deletion before re-entry
- **One-tap record creation** — Bypassing chat breaks the conversational log and confirmation loop
- **Prompts from non-greeting messages** — Only the greeting carries pattern-derived context
- **Persisting prompt list across app restarts** — Session-only; simplicity over persistence
- **Restoring consumed prompts** — Once a prompt is used and removed, it is gone for the session

## Dependencies

- `suggestedPrompts` JSON field from server greeting — Already implemented server-side; no server change needed — **resolved**
- `ChatConfig.delimiter` (`--//--`) — Defined in `lib/configs/chat_config.dart` — **resolved**
- `StorageService.keyUserPattern` — Already retrieved and passed in `sendAdaptiveGreeting()` — **resolved**
- `ai-pattern-analyze` epic — Upstream producer of `long_term_user_pattern` — **complete**

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2, NFR-3]
scale: medium
discovery_mode: express
validation_status: warning
last_validated: 2026-04-03T04:07:08Z
