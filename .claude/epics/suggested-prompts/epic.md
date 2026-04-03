---
name: suggested-prompts
status: backlog
created: 2026-04-03T04:11:37Z
progress: 0%
priority: P1
prd: .claude/prds/suggested-prompts.md
task_count: 4
github: "https://github.com/dainn67/wallet-ai/issues/154"
---

# Epic: suggested-prompts

## Overview

We'll parse the `suggestedPrompts` JSON object from the greeting response and surface it as an interactive chip bar above the chat input. The approach is additive: a new `SuggestedPrompt` model, a new parsing branch in `ChatProvider._handleStream()` (alongside the existing record array branch), new provider state fields for prompt selection, and a single new widget (`SuggestedPromptsBar`) inserted into `ChatTab`'s existing Column layout. We chose to keep all prompt state in `ChatProvider` (not a separate notifier) because it tightly couples to the greeting lifecycle and `sendMessage()` — adding a second notifier would create cross-provider coordination complexity for minimal benefit. The main risk is the JSON branch detection: the existing parser assumes JSON after `--//--` is always a record array, so we must check for the `suggestedPrompts` key before falling back to array parsing.

## Architecture Decisions

### AD-1: Prompt state lives in ChatProvider, not a separate notifier
**Context:** The suggested prompts are produced by `_handleStream()` (greeting path) and consumed by `sendMessage()` (for removal on send). Both methods live in `ChatProvider`.
**Decision:** Add `_suggestedPrompts`, `_activePromptIndex`, and `_showingActions` fields directly to `ChatProvider`.
**Alternatives rejected:** Separate `SuggestedPromptsNotifier` — would require `ProxyProvider` wiring to sync with `ChatProvider.sendMessage()` and greeting lifecycle. Adds coordination overhead with no clear benefit.
**Trade-off:** `ChatProvider` grows slightly larger, but the state is tightly coupled to chat lifecycle and avoids cross-provider bugs.
**Reversibility:** Easy — extract to separate notifier later if ChatProvider grows too large.

### AD-2: JSON branch detection by key check, not try-catch
**Context:** After `--//--` split, the JSON part can be either `[{record...}]` (array) or `{"suggestedPrompts": [...]}` (object). We need to route to the correct parser.
**Decision:** Decode JSON first, then check type: if result is `Map` and contains `suggestedPrompts` key → parse prompts. If result is `List` → parse records (existing path). Wrap both in try-catch for NFR-3.
**Alternatives rejected:** Try parsing as records first, catch failure, then try prompts — fragile and hides real errors. Regex-based detection — unnecessary when `jsonDecode` already gives us the type.
**Trade-off:** One extra `jsonDecode` call regardless of type, but it's a single JSON parse either way — no performance difference.
**Reversibility:** Easy — the branch is a simple if/else.

### AD-3: SuggestedPromptsBar as a standalone widget
**Context:** The chip bar sits between the message list and input area in ChatTab's Column. It has two display modes (prompts vs actions) and handles tap callbacks.
**Decision:** Create `lib/components/suggested_prompts_bar.dart` as a stateless widget. It receives data from `ChatProvider` via `Consumer` in `ChatTab`. The widget does not own `TextEditingController` — it exposes callbacks (`onPromptTap`, `onActionTap`) that `ChatTab` handles to update the controller.
**Alternatives rejected:** Building inline in ChatTab — makes ChatTab harder to test and read. Making it stateful — unnecessary since all state lives in ChatProvider.
**Trade-off:** Clean separation but requires ChatTab to wire callbacks. Minimal overhead.
**Reversibility:** Easy — it's a widget file.

## Technical Approach

### Model Layer
- **New file:** `lib/models/suggested_prompt.dart`
- Create `SuggestedPrompt` class with `String prompt` and `List<String> actions` fields
- Follow existing `Record.fromMap()` / `toMap()` pattern from `lib/models/record.dart`
- Factory constructor `SuggestedPrompt.fromJson(Map<String, dynamic> json)` for parsing
- No `copyWith` needed — model is read-only after parsing

### Provider Layer
- **Modify:** `lib/providers/chat_provider.dart`
- **New state fields:**
  - `List<SuggestedPrompt> _suggestedPrompts = []` with public getter
  - `int? _activePromptIndex` — index of the selected prompt (null = none selected)
  - `bool _showingActions = false` — true when action chips replace prompt chips
- **New methods:**
  - `selectPrompt(int index)` — sets `_activePromptIndex`, `_showingActions = actions.isNotEmpty`, notifies
  - `selectAction()` — sets `_showingActions = false`, notifies (text append done by widget)
  - `_removeActivePrompt()` — removes prompt at `_activePromptIndex` from list, resets index and showingActions, notifies
- **Modified methods:**
  - `_handleStream()` onDone: after splitting by delimiter, `jsonDecode` the JSON part. If result is `Map<String, dynamic>` containing `suggestedPrompts` key → parse into `List<SuggestedPrompt>`, set `_suggestedPrompts`, notify. If result is `List` → existing record parsing. Wrap in try-catch (NFR-3).
  - `sendMessage()`: before clearing state, check if `_activePromptIndex != null` → call `_removeActivePrompt()`. Reset `_activePromptIndex = null` and `_showingActions = false`.

### UI Layer
- **New file:** `lib/components/suggested_prompts_bar.dart`
- `SuggestedPromptsBar` — stateless widget receiving:
  - `List<SuggestedPrompt> prompts`
  - `int? activePromptIndex`
  - `bool showingActions`
  - `Function(int) onPromptTap`
  - `Function(int) onActionTap`
- When `showingActions == false`: render horizontal `ListView.builder` of prompt chips
- When `showingActions == true`: render horizontal `ListView.builder` of action chips from `prompts[activePromptIndex].actions`
- Use `SingleChildScrollView(scrollDirection: Axis.horizontal)` or horizontal `ListView` with fixed height (~48px)
- Style: `ActionChip` or `ChoiceChip` with Poppins font, matching existing app theme

- **Modify:** `lib/screens/home/tabs/chat_tab.dart`
- Insert `SuggestedPromptsBar` into the existing `Column` between the streaming indicator and `_buildInputArea()`
- Wrap with `Consumer<ChatProvider>` to reactively show/hide
- Wire `onPromptTap`: clear `_controller.text`, set to `prompt.prompt`, call `chatProvider.selectPrompt(index)`, request focus
- Wire `onActionTap`: append `" ${action}"` to `_controller.text`, call `chatProvider.selectAction()`
- In existing `_handleSend()`: no changes needed — `chatProvider.sendMessage()` already handles prompt removal internally

### Test Layer
- **Modify:** `test/providers/chat_provider_test.dart`
  - Test: greeting with `suggestedPrompts` JSON → prompts parsed correctly
  - Test: greeting with record array → prompts remain empty (no regression)
  - Test: greeting with malformed JSON → prompts empty, no crash
  - Test: `selectPrompt()` → state updates correctly
  - Test: `selectAction()` → `_showingActions` becomes false
  - Test: `sendMessage()` with active prompt → prompt removed from list
  - Test: `sendMessage()` without active prompt → list unchanged
- **Modify:** `test/screens/chat_tab_test.dart`
  - Test: chip bar visible when `suggestedPrompts` non-empty
  - Test: chip bar hidden when `suggestedPrompts` empty
  - Test: tap prompt chip → input updated

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
|-----------------|---------------|---------|--------------|
| FR-1: Parse suggestedPrompts from greeting JSON | §Technical Approach / Provider Layer — new JSON branch in `_handleStream()` | T1 | Unit test: 3 scenarios (with prompts, without JSON, with records) |
| FR-2: Display prompt chip bar above input | §Technical Approach / UI Layer — SuggestedPromptsBar + ChatTab Column insertion | T3 | Widget test + manual QA |
| FR-3: Prompt tap pre-fills input and replaces with actions | §Technical Approach / Provider Layer (`selectPrompt`) + UI Layer (onPromptTap wiring) | T2, T3 | Unit test (provider state) + widget test (tap interaction) |
| FR-4: Action tap appends to input and hides actions | §Technical Approach / Provider Layer (`selectAction`) + UI Layer (onActionTap wiring) | T2, T3 | Unit test + widget test |
| FR-5: Send removes active prompt | §Technical Approach / Provider Layer (`sendMessage` modification) | T2 | Unit test: 4 scenarios (active, no active, last consumed, input cleared) |
| NFR-1: No layout shift | §AD-3 / Widget renders reactively via Consumer, same frame as notifyListeners | T3 | Manual QA on mid-range device |
| NFR-2: No overlap with messages | §Technical Approach / UI Layer — Column layout with conditional chip bar | T3 | Manual QA: scroll to bottom with chips visible |
| NFR-3: Graceful parse failure | §AD-2 / try-catch around jsonDecode in _handleStream | T1 | Unit test: malformed JSON → empty prompts, no crash |
| NTH-1: Manual dismiss | Deferred to follow-up | — | — |

## Implementation Strategy

### Phase 1: Foundation (T1)
**What:** SuggestedPrompt model + JSON parsing branch in ChatProvider.
**Why:** Everything depends on parsed prompt data being available in the provider.
**Exit criterion:** `ChatProvider.suggestedPrompts` correctly populated from greeting JSON; existing record parsing unbroken; malformed JSON handled gracefully. All provider parsing tests pass.

### Phase 2: Core Interaction (T2, T3 — sequential)
**What:** Provider state methods for prompt selection/action/removal (T2), then UI widget + ChatTab integration (T3).
**Why:** T3 depends on T2's methods to wire callbacks. T2 is provider-only (no UI), T3 is UI-only (no provider logic).
**Exit criterion:** Full 3-step flow works end-to-end: tap prompt → input filled + actions shown → tap action → appended → send → prompt removed. Widget tests pass.

### Phase 3: Polish (T4)
**What:** Comprehensive test coverage for all scenarios + edge cases.
**Why:** Ensure no regression on existing record parsing, verify edge cases (no actions, last prompt consumed, input cleared).
**Exit criterion:** All unit and widget tests pass. `fvm flutter test` green.

## Task Breakdown

##### T1: SuggestedPrompt model + greeting JSON parsing branch
- **Phase:** 1 | **Parallel:** no | **Est:** 1d | **Depends:** — | **Complexity:** moderate
- **What:** Create `lib/models/suggested_prompt.dart` with `prompt` (String) and `actions` (List\<String\>) fields, following `Record.fromMap()` pattern. Then modify `ChatProvider._handleStream()` onDone block: after splitting by `ChatConfig.delimiter`, call `jsonDecode()` on the JSON string. If result is a `Map<String, dynamic>` with `suggestedPrompts` key, parse into `List<SuggestedPrompt>` and assign to new `_suggestedPrompts` field. If result is a `List`, fall through to existing record parsing. Wrap in try-catch for NFR-3 (parse failure → `_suggestedPrompts` stays empty, greeting continues normally).
- **Key files:** `lib/models/suggested_prompt.dart` (new), `lib/providers/chat_provider.dart` (modify onDone block)
- **PRD requirements:** FR-1, NFR-3
- **Key risk:** The existing onDone block directly does `jsonDecode(jsonString)` and casts to `List<dynamic>` — changing this to handle both Map and List requires careful refactoring to avoid breaking the record path.
- **Interface produces:** `ChatProvider.suggestedPrompts` getter (List\<SuggestedPrompt\>), `SuggestedPrompt` model class.

##### T2: ChatProvider prompt interaction state management
- **Phase:** 2 | **Parallel:** no | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Add `_activePromptIndex` (int?) and `_showingActions` (bool) fields to ChatProvider with public getters. Add `selectPrompt(int index)` that sets active index and `_showingActions = prompts[index].actions.isNotEmpty`, then notifies. Add `selectAction()` that sets `_showingActions = false` and notifies. Modify `sendMessage()`: before the existing logic, if `_activePromptIndex != null`, remove that prompt from `_suggestedPrompts` list, reset `_activePromptIndex = null` and `_showingActions = false`, notify.
- **Key files:** `lib/providers/chat_provider.dart`
- **PRD requirements:** FR-3, FR-4, FR-5
- **Key risk:** `sendMessage()` currently returns early if content is empty — need to ensure prompt removal happens before the early return check, or after it (depending on whether empty-send should remove the prompt).
- **Interface receives from T1:** `_suggestedPrompts` list field, `SuggestedPrompt` model class
- **Interface produces:** `selectPrompt(int)`, `selectAction()`, `activePromptIndex` getter, `showingActions` getter — consumed by T3 widget wiring.

##### T3: SuggestedPromptsBar widget + ChatTab integration
- **Phase:** 2 | **Parallel:** no | **Est:** 1d | **Depends:** T2 | **Complexity:** moderate
- **What:** Create `lib/components/suggested_prompts_bar.dart` as a stateless widget. It receives `prompts`, `activePromptIndex`, `showingActions`, `onPromptTap(int)`, `onActionTap(int)` and renders a horizontal scrollable row of `ActionChip` widgets. When `showingActions` is false, shows prompt chips from `prompts`; when true, shows action strings from `prompts[activePromptIndex].actions`. Then modify `lib/screens/home/tabs/chat_tab.dart`: insert a `Consumer<ChatProvider>` block between the streaming indicator and `_buildInputArea()` that conditionally renders `SuggestedPromptsBar` when `provider.suggestedPrompts.isNotEmpty`. Wire `onPromptTap` to: clear `_controller.text`, set `_controller.text = prompt.prompt`, position cursor at end, call `provider.selectPrompt(index)`, request focus. Wire `onActionTap` to: append `" ${actionText}"` to `_controller.text`, position cursor at end, call `provider.selectAction()`.
- **Key files:** `lib/components/suggested_prompts_bar.dart` (new), `lib/screens/home/tabs/chat_tab.dart` (modify Column children)
- **PRD requirements:** FR-2, FR-3, FR-4, FR-5, NFR-1, NFR-2
- **Key risk:** Column layout needs to account for chip bar height dynamically — if using Expanded for the message list, adding a conditional widget between Expanded and the input should work naturally, but must verify no overflow on small screens.
- **Interface receives from T2:** `selectPrompt(int)`, `selectAction()`, `suggestedPrompts`, `activePromptIndex`, `showingActions` getters.

##### T4: Unit tests + widget tests
- **Phase:** 3 | **Parallel:** no | **Est:** 1d | **Depends:** T3 | **Complexity:** moderate
- **What:** Add provider unit tests in `test/providers/chat_provider_test.dart`: (1) greeting with suggestedPrompts JSON → prompts parsed, (2) greeting with record array → prompts empty, (3) malformed JSON → prompts empty + no crash, (4) selectPrompt → state updates, (5) selectAction → showingActions false, (6) sendMessage with active prompt → removed, (7) sendMessage without active → unchanged, (8) last prompt consumed → list empty. Add widget tests in `test/screens/chat_tab_test.dart`: (1) chip bar visible when prompts non-empty, (2) chip bar hidden when empty, (3) tap prompt → input updated. Follow existing mocktail patterns: `MockChatApiService`, `StreamController<ChatStreamResponse>` for streaming simulation.
- **Key files:** `test/providers/chat_provider_test.dart` (modify), `test/screens/chat_tab_test.dart` (modify)
- **PRD requirements:** FR-1, FR-2, FR-3, FR-4, FR-5, NFR-3
- **Key risk:** Mocking `suggestedPrompts` getter in widget tests requires updating the existing `MockChatProvider` to include new getters — must not break existing test setup.

## Risks & Mitigations

| Risk | Severity | Likelihood | Impact | Mitigation |
|------|----------|------------|--------|------------|
| Refactoring `_handleStream()` onDone breaks record parsing | High | Med | Records stop saving after greeting — core feature broken | T1 tests explicitly verify record path still works; run full `fvm flutter test` after T1 |
| JSON branch: `jsonDecode` returns `dynamic`, type casting can throw | Med | Med | Crash on unexpected JSON shape | Wrap in try-catch, type-check with `is Map<String, dynamic>` and `is List` before casting |
| Column layout overflow when chip bar added between Expanded and input | Med | Med | Bottom overflow on small screens | SuggestedPromptsBar has fixed max height (~48px); message list Expanded absorbs remaining space naturally |
| `sendMessage()` early-return on empty content skips prompt removal | Med | Low | Active prompt stuck in state, removed on wrong send | Place prompt removal logic BEFORE the empty-content check, or ensure it runs regardless of content |
| Existing widget tests break due to new `suggestedPrompts` getter | Low | High | CI fails until tests updated | T4 updates mock provider to stub `suggestedPrompts`, `activePromptIndex`, `showingActions` getters with empty defaults |

## Dependencies

- `suggestedPrompts` JSON from server greeting — already implemented, no server change needed — **resolved**
- `ChatConfig.delimiter` — defined in `lib/configs/chat_config.dart` — **resolved**
- `RecordProvider` for `sendMessage()` — already wired via refactor-code epic — **resolved**
- `record-provider` epic (backlog) — does NOT block this epic; they touch different parts of the provider — **no conflict**

## Success Criteria (Technical)

| PRD Criterion | Technical Metric | Target | How to Measure |
|---------------|------------------|--------|----------------|
| Functional coverage | `suggestedPrompts` parsed and chip bar rendered for returning users | 100% of greeting-with-prompts paths | Unit test: parse JSON → list non-empty; Widget test: bar visible |
| No regression | Existing record parsing + ChatProvider tests unchanged | 0 test failures | `fvm flutter test` — all existing tests pass after T1 |
| New user parity | Chip bar not rendered when `suggestedPrompts` is empty | UI identical | Widget test: empty prompts → no SuggestedPromptsBar in widget tree |
| Parse resilience | Malformed JSON does not crash | 0 crashes | Unit test: inject `{"suggestedPrompts": "invalid"}` → empty list, no exception |
| Logging speed | Tap prompt → tap action → send completes in under 5s | ≤5 seconds | Manual QA stopwatch on 3 scenarios |

## Estimated Effort

- **Total:** 4 tasks, ~4 days
- **Critical path:** T1 → T2 → T3 → T4 (fully sequential — each task depends on the previous)
- **Phase 1 (Foundation):** 1 day — model + parsing
- **Phase 2 (Core):** 2 days — provider state + UI widget
- **Phase 3 (Polish):** 1 day — tests

## Deferred / Follow-up

- **NTH-1: Manual dismiss of chip bar** — Deferred because it requires an additional UI element (✕ button) and provider state (`_dismissed` bool). Low value for MVP since users can simply ignore the chip bar. Will add in a follow-up if user feedback indicates the bar feels intrusive.
