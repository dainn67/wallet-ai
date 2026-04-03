---
epic: suggested-prompts
phase: A
generated: 2026-04-03T04:43:01Z
assessment: EPIC_GAPS
quality_score: 3.8/5
total_issues: 5
closed_issues: 4
open_issues: 1
---

# Epic Verification Report: suggested-prompts
## Phase A: Semantic Review

---

## Analysis 1: Coverage Matrix

The acceptance criteria are derived from the PRD's functional requirements (FR-1 through FR-5), non-functional requirements (NFR-1 through NFR-3), and the user story acceptance criteria.

| # | Acceptance Criteria | Issue(s) | Status | Evidence |
|---|---------------------|----------|--------|----------|
| 1 | FR-1: Parse `suggestedPrompts` object from greeting JSON into `List<SuggestedPrompt>` | #155 (T1) | ✅ Covered | `chat_provider.dart` lines 182-188: checks `decoded is Map<String, dynamic>` with `suggestedPrompts` key, parses into list. Commit `9e5250b`. Unit test confirms parsing. |
| 2 | FR-1 Scenario: Greeting without JSON (new user) — suggestedPrompts remains empty | #155 (T1) | ✅ Covered | No delimiter = no JSON branch entered. Test `greeting with no delimiter leaves suggestedPrompts empty` passes. |
| 3 | FR-1 Scenario: Greeting with record array — records parsed, suggestedPrompts empty | #155 (T1) | ✅ Covered | `decoded is List` branch falls through to record parsing (lines 189-229). Test `greeting with record array does not populate suggestedPrompts` confirms no regression. |
| 4 | FR-2: Display prompt chip bar above chat input when suggestedPrompts non-empty | #157 (T3) | ✅ Covered | `chat_tab.dart` lines 113-124: `Consumer<ChatProvider>` renders `SuggestedPromptsBar` conditionally. Widget test `shows SuggestedPromptsBar when prompts non-empty` confirms. |
| 5 | FR-2: No chip row when suggestedPrompts is empty | #157 (T3) | ✅ Covered | Line 115: `if (provider.suggestedPrompts.isEmpty) return const SizedBox.shrink()`. Widget test `hides SuggestedPromptsBar when prompts empty` confirms. |
| 6 | FR-3: Prompt tap pre-fills input and replaces prompt chips with action chips | #156 (T2), #157 (T3) | ✅ Covered | `selectPrompt(int)` sets `_activePromptIndex` and `_showingActions`. `_onPromptTap` in ChatTab clears/sets controller text, requests focus. `SuggestedPromptsBar` switches display mode based on `showingActions`. |
| 7 | FR-3: Prompt with no actions — chip bar disappears | #156 (T2), #157 (T3) | ✅ Covered | `selectPrompt` sets `_showingActions = actions.isNotEmpty`, so false for empty actions. `SuggestedPromptsBar` returns `SizedBox.shrink()` when actions are empty in action mode. Unit test `selectPrompt with empty actions` confirms. |
| 8 | FR-4: Action tap appends text to input and hides action chips | #156 (T2), #157 (T3) | ✅ Covered | `selectAction()` sets `_showingActions = false`. `_onActionTap` in ChatTab appends action text. Unit test `selectAction sets showingActions to false` confirms. |
| 9 | FR-5: Send removes active prompt from list | #156 (T2) | ✅ Covered | `sendMessage()` calls `_removeActivePrompt()` before content check. Unit tests cover: active prompt removed, no active prompt unchanged, last prompt consumed, empty content with active prompt. |
| 10 | FR-5: Send without active prompt — list unchanged | #156 (T2) | ✅ Covered | `sendMessage` checks `_activePromptIndex != null` before removal. Test `sendMessage without active prompt leaves suggestedPrompts unchanged` confirms. |
| 11 | FR-5: Last prompt consumed — chip bar disappears | #156 (T2), #157 (T3) | ✅ Covered | After removal, list becomes empty, SuggestedPromptsBar renders `SizedBox.shrink()`. Test `sendMessage with last active prompt results in empty suggestedPrompts` confirms. |
| 12 | NFR-1: No layout shift on chip bar appearance | #157 (T3) | ⚠️ Partial | Widget renders via Consumer in same frame as `notifyListeners()` — architecturally sound. But no automated test or documented QA verification exists. |
| 13 | NFR-2: Chip bar does not overlap message content | #157 (T3) | ⚠️ Partial | Column layout with `Expanded` for message list should handle this. Fixed 48px height on SuggestedPromptsBar. No automated test or documented QA verification exists. |
| 14 | NFR-3: Graceful parse failure | #155 (T1) | ✅ Covered | try-catch wraps entire JSON decode block (line 181-232). Test `malformed suggestedPrompts JSON leaves suggestedPrompts empty and does not crash` confirms. |
| 15 | US-1 AC: Horizontal scrollable chip row | #157 (T3) | ✅ Covered | `SingleChildScrollView(scrollDirection: Axis.horizontal)` in `suggested_prompts_bar.dart` lines 30-32 and 51-53. |
| 16 | US-2 AC: Text field receives focus after tap | #157 (T3) | ✅ Covered | `_onPromptTap` calls `FocusScope.of(context).requestFocus(widget.focusNode)` (line 65). |
| 17 | US-3 AC: Action chip row disappears after action tap | #156 (T2), #157 (T3) | ✅ Covered | `selectAction()` sets `_showingActions = false`, widget re-renders to prompt mode or hides. |
| 18 | Living Docs: `docs/features/` updated | — | ❌ Missing | No `docs/features/suggested-prompts.md` file exists. No mention of suggested prompts in any docs/features file. |
| 19 | Living Docs: `project_context/` updated | — | ❌ Missing | No mention of suggested prompts in `project_context/architecture.md`, `context.md`, or `coding_style.md`. |
| 20 | Epic issue #154 status | #154 | ⚠️ Partial | Epic issue #154 is still OPEN on GitHub despite all 4 tasks being closed. |

**Summary:** 14/20 fully covered, 3 partial, 3 missing.

---

## Analysis 2: Gap Report

**Gap #1: Missing feature documentation in `docs/features/`**
- Category: 5 (Quality Gap)
- Severity: Medium
- Related issues: All (#155-#158)
- Description: The CLAUDE.md Living Docs Mandate requires a `docs/features/suggested-prompts.md` file for any new feature. This file does not exist.
- Evidence: `grep -ri "suggested.prompt" docs/` returns no results.
- Recommendation: Create `docs/features/suggested-prompts.md` documenting the feature behavior and technical flow.
- Estimated effort: Small

**Gap #2: Missing `project_context/` updates**
- Category: 5 (Quality Gap)
- Severity: Medium
- Related issues: All (#155-#158)
- Description: The CLAUDE.md Living Docs Mandate requires updating `project_context/architecture.md`, `context.md`, and `coding_style.md` when a new feature is completed. None of these files mention the suggested prompts feature, the new `SuggestedPrompt` model, or the `SuggestedPromptsBar` widget.
- Evidence: `grep -ri "suggested.prompt" project_context/` returns no results.
- Recommendation: Update `project_context/context.md` (add model, widget, provider fields) and `project_context/architecture.md` (note ChatProvider expansion).
- Estimated effort: Small

**Gap #3: NFR-1/NFR-2 lack verification evidence**
- Category: 5 (Quality Gap)
- Severity: Low
- Related issues: #157 (T3)
- Description: NFR-1 (no layout shift) and NFR-2 (no message overlap) are design-level requirements verified only by architecture (Column + Consumer layout). No automated test or QA sign-off is documented.
- Evidence: No widget test verifies bottom padding or layout shift. Handoff `latest.md` does not mention QA testing.
- Recommendation: Add to Phase B manual QA checklist. These are difficult to automate; manual verification is acceptable.
- Estimated effort: Small

**Gap #4: Epic issue #154 still OPEN on GitHub**
- Category: 4 (Missing Requirement — process gap)
- Severity: Low
- Related issues: #154
- Description: The epic tracking issue is still OPEN despite all 4 child tasks (001-004) being closed.
- Evidence: `05-issue-status.md`: "#154 State: OPEN"
- Recommendation: Close issue #154 on GitHub after verification passes.
- Estimated effort: Small

**Gap #5: No epic context file**
- Category: 5 (Quality Gap)
- Severity: Low
- Related issues: All
- Description: `.claude/context/epics/suggested-prompts.md` does not exist. While handoff notes exist, the accumulated epic context file is missing.
- Evidence: `07-epic-context.md`: "No epic context file found"
- Recommendation: Create epic context file or accept as non-blocking since handoff notes provide equivalent information.
- Estimated effort: Small

**Gap #6: No active-interfaces.md documentation**
- Category: 5 (Quality Gap)
- Severity: Low
- Related issues: All
- Description: No `active-interfaces.md` file documents the new public APIs added to ChatProvider (`suggestedPrompts`, `activePromptIndex`, `showingActions`, `selectPrompt()`, `selectAction()`).
- Evidence: `12-active-interfaces.md`: "No active-interfaces.md found"
- Recommendation: Create or update active-interfaces.md. Low priority since interfaces are well-documented in the epic plan and code.
- Estimated effort: Small

**Gap #7: Widget test coverage incomplete — no tap interaction tests**
- Category: 5 (Quality Gap)
- Severity: Medium
- Related issues: #158 (T4)
- Description: The epic plan specified widget tests for "tap prompt chip -> input updated" but the actual widget tests only verify visibility (bar present/absent). No test verifies tap interaction, input pre-fill, or action append at the widget level.
- Evidence: `chat_tab_test.dart` has 2 widget tests (visibility only). Epic plan T4 specified: "tap prompt -> input updated" test. Handoff `latest.md` lists only 2 visibility tests.
- Recommendation: Add widget interaction tests for prompt tap and action tap. These are important for regression protection.
- Estimated effort: Small

---

## Analysis 3: Integration Risk Map

| Dependency | Interface | Documented? | Consumer Correct? | Integration Test? | Risk |
|---|---|---|---|---|---|
| T1 -> T2: `_suggestedPrompts` list, `SuggestedPrompt` model | `List<SuggestedPrompt>` field in ChatProvider | Yes (epic plan) | Yes — T2 uses same field directly | Unit tests cover state transitions | Low |
| T2 -> T3: `selectPrompt()`, `selectAction()`, getters | Public methods/getters on ChatProvider | Yes (epic plan) | Yes — ChatTab wires callbacks correctly | Widget visibility tests only, no interaction tests | Medium |
| T1 parsing -> Server JSON format | `{"suggestedPrompts": [{"prompt": str, "actions": [str]}]}` | Yes (PRD) | Yes — parser matches expected schema | Unit test with realistic JSON | Low |
| ChatProvider.sendMessage -> prompt removal | `_removeActivePrompt()` called before content check | Yes (epic plan risk table) | Yes — correctly placed before early return | Unit tests cover 4 scenarios | Low |
| SuggestedPromptsBar -> ChatTab Column layout | Fixed 48px height, Consumer-driven | Yes (AD-3) | Yes — inserted between streaming indicator and input | No layout overflow test | Medium |

**Overall integration risk: LOW.** The sequential implementation (T1->T2->T3->T4) and single-provider architecture minimize cross-component risk. The main medium-risk area is the absence of widget interaction tests for the T2->T3 interface.

---

## Analysis 4: Quality Scorecard

| Criteria | Score (1-5) | Rationale |
|----------|------------|-----------|
| Requirements Coverage | 4 | 14/17 functional criteria fully covered. NFR-1/NFR-2 partial (no QA evidence). All core FR scenarios implemented and tested. |
| Implementation Completeness | 5 | All production code implemented: model, provider state, widget, ChatTab integration. No stubs or placeholder code. |
| Test Coverage | 3 | 13 unit tests + 2 widget tests cover core scenarios. Missing: widget interaction tests (tap), no formal coverage report. 4 pre-existing failures unrelated. |
| Integration Confidence | 4 | Sequential implementation, single-provider architecture. All interfaces match. Column layout is standard Flutter pattern. No cross-provider coordination needed. |
| Documentation Quality | 3 | Architecture decisions well-documented. Handoff notes present. Missing: feature docs, project_context updates, epic context file, active-interfaces. |
| Regression Risk | 4 | Existing record parsing path verified by unit test. Additive changes only — no modification to existing parsing logic. Try-catch prevents crashes. |
| **Average Score** | **3.8/5** | |

---

## Analysis 5: Recommendations

**Overall Assessment: EPIC_GAPS** — All functional requirements are implemented and tested. Gaps are documentation and test coverage related. No critical gaps. Recommend addressing medium-severity gaps before shipping.

**Specific actions (prioritized by severity):**

1. **[MEDIUM] Add missing documentation** — Create `docs/features/suggested-prompts.md` and update `project_context/context.md` + `project_context/architecture.md` to include the new feature. This is a project mandate (CLAUDE.md Living Docs).

2. **[MEDIUM] Add widget interaction tests** — The epic plan specified tap interaction tests that were not delivered in T4. Add at least: (a) tap prompt chip verifies input text updated, (b) tap action chip verifies text appended. This provides regression protection for the core user flow.

3. **[LOW] Close epic issue #154 on GitHub** — All 4 tasks are closed but the parent epic issue remains open. Close it after verification passes to keep issue tracking accurate.

**New issues to create (if any):**
- "docs: Add suggested-prompts feature documentation and update project_context" — Labels: documentation, suggested-prompts. Covers Gaps #1 and #2.
- "test: Add widget interaction tests for SuggestedPromptsBar tap flow" — Labels: testing, suggested-prompts. Covers Gap #7.

---

## Analysis 6: Phase B Preparation

**E2E Test Scenarios to write:**

| # | Scenario | User Flow | Modules involved | Priority |
|---|----------|-----------|------------------|----------|
| 1 | Returning user sees prompt chips after greeting | Launch app with stored pattern -> greeting loads -> verify chips visible | ChatApiService, ChatProvider, ChatTab, SuggestedPromptsBar | P1 |
| 2 | Full 3-step flow: prompt -> action -> send | Tap prompt chip -> verify input filled -> tap action chip -> verify appended -> send -> verify prompt removed | ChatProvider, ChatTab, SuggestedPromptsBar | P1 |
| 3 | New user sees no chips | Launch app without pattern -> greeting loads -> verify no chip bar | ChatApiService, ChatProvider, ChatTab | P1 |
| 4 | Prompt with no actions | Tap prompt with empty actions -> verify input filled, no action bar, ready to send | ChatProvider, ChatTab, SuggestedPromptsBar | P2 |
| 5 | Free-text send preserves prompts | With chips visible, type and send without tapping a chip -> verify all prompts remain | ChatProvider, ChatTab | P2 |
| 6 | Last prompt consumed | Use all prompts one by one -> verify chip bar disappears after last | ChatProvider, ChatTab | P2 |
| 7 | Malformed JSON resilience | Server returns bad suggestedPrompts JSON -> verify no crash, no chip bar | ChatProvider | P2 |

**Integration Test Points:**
- [ChatProvider parsing] <-> [Server JSON format]: Test with realistic greeting payloads containing suggestedPrompts
- [ChatProvider state] <-> [SuggestedPromptsBar rendering]: Test that provider state changes correctly trigger widget rebuilds
- [ChatTab._onPromptTap] <-> [TextEditingController]: Test that tap callback correctly updates text field content and cursor position

**Smoke Test Checklist:**
- [ ] App launches without crash on returning user with stored pattern
- [ ] Chip bar appears after greeting with suggestedPrompts
- [ ] Tap prompt chip -> input pre-filled, action chips shown (if actions exist)
- [ ] Tap action chip -> amount appended, action chips hidden
- [ ] Send message -> used prompt removed from chip bar
- [ ] No chip bar for new user (no stored pattern)
- [ ] Chip bar does not overlap last chat message (scroll to bottom test)
- [ ] No layout shift when chip bar appears with greeting
- [ ] Record parsing still works (existing flow regression check)
