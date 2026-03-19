---
name: update-message-body
status: completed
created: 2026-03-19T06:35:00Z
updated: 2026-03-19T10:25:00Z
completed: 2026-03-19T10:25:00Z
progress: 100%
priority: P1
prd: .claude/prds/update-message-body.md
task_count: 5
github: "https://github.com/dainn67/wallet-ai/issues/63"
---

# Epic: update-message-body (Completed)

## Final Summary
Streamlined the AI record creation process by providing specific schema context (money sources and categories with their IDs) to the AI. Refactored the `ChatProvider` parser to use these direct ID mappings, removing brittle string-matching logic and improving system robustness. Added comprehensive unit and integration tests to verify the new flow.


## Architecture Decisions
### AD-1: Serialized Context Strings
**Context:** The AI needs a simple way to know which IDs correspond to which names.
**Decision:** Format the lists as `id-Name` (e.g., "1-Bank, 2-Food") and send them as plain strings in the `inputs` field of the Dify request.
**Alternatives rejected:** Sending full JSON objects (rejected to save prompt tokens and keep the system prompt simple).
**Trade-off:** Minimal token usage vs. slightly more work for the AI to parse the prompt (user will handle prompt tuning).
**Reversibility:** High.

### AD-2: Provider-to-Provider Dependency
**Context:** `ChatProvider` needs access to the current categories and sources managed by `RecordProvider`.
**Decision:** Inject `RecordProvider` into `ChatProvider` or pass the required data during the `sendMessage` call.
**Alternatives rejected:** `ChatProvider` calling `RecordRepository` directly (rejected because we want to use the Provider's cached data).
**Trade-off:** Adds a dependency between providers.
**Reversibility:** Medium.

## Technical Approach
### Service Layer
- **Formatting Helpers**: Add static methods to `ChatApiService` to convert `List<MoneySource>` and `List<Category>` into the `id-Name` string format.
- **API Request**: Update `streamChat` to accept `categoryList` and `moneySourceList` and inject them into the `inputs` map if not empty.

### Provider Layer
- **Dependency**: Update `ChatProvider` to hold a reference to `RecordProvider`.
- **Flow**: In `sendMessage`, fetch the formatted context strings and pass them to the service.
- **Parser**: Refactor the `onDone` listener to expect `source_id` and `category_id` in the JSON response from the AI.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Formatting Helpers | §Service Layer | T1 | Unit tests for string formatting |
| FR-2: updated streamChat | §Service Layer | T2 | Inspect network payload |
| FR-3: Provider Integration | §Provider Layer | T3 | Verify data flow in debugger |
| FR-4: Parser Refactor | §Provider Layer | T4 | Successful record creation with IDs |
| FR-5: Graceful Fallbacks | §Provider Layer | T4 | Record created with ID 1 on failure |
| NFR-1: Robustness | §Provider Layer | T4 | Error logging on malformed JSON |

## Implementation Strategy
### Phase 1: Service Enhancements
Define the formatting logic and update the network interface.
### Phase 2: Provider Integration
Link the providers and update the message sending flow.
### Phase 3: Parser Migration
Switch the parser from string-matching to ID-direct mapping and remove legacy code.

## Task Breakdown

##### T1: Service Formatting Helpers
- **Phase:** 1 | **Parallel:** yes | **Est:** 0.3d | **Depends:** — | **Complexity:** simple
- **What:** Add static helper methods to `ChatApiService` to format `List<MoneySource>` and `List<Category>` into `id-Name` strings.
- **Key files:** `lib/services/chat_api_service.dart`
- **PRD requirements:** FR-1
- **Key risk:** None.

##### T2: Update streamChat Interface
- **Phase:** 1 | **Parallel:** no | **Est:** 0.3d | **Depends:** T1 | **Complexity:** simple
- **What:** Modify `ChatApiService.streamChat` to accept context strings and include them in the `inputs` field of the API request.
- **Key files:** `lib/services/chat_api_service.dart`
- **PRD requirements:** FR-2
- **Key risk:** API schema mismatch if `inputs` keys are incorrect.

##### T3: Integrate Providers
- **Phase:** 2 | **Parallel:** no | **Est:** 0.4d | **Depends:** T2 | **Complexity:** simple
- **What:** Update `ChatProvider` to receive/hold a `RecordProvider` reference. Update `sendMessage` to pass formatted context strings to the service.
- **Key files:** `lib/providers/chat_provider.dart`
- **PRD requirements:** FR-3
- **Key risk:** Circular dependency if not handled via `ProxyProvider` or constructor injection.

##### T4: Refactor AI Parser
- **Phase:** 3 | **Parallel:** no | **Est:** 0.7d | **Depends:** T3 | **Complexity:** moderate
- **What:** Rewrite the `onDone` parsing logic in `ChatProvider`. It should now expect `source_id` and `category_id` in the JSON response. Remove the legacy `getMoneySourceByName` logic.
- **Key files:** `lib/providers/chat_provider.dart`
- **PRD requirements:** FR-4, FR-5, NFR-1
- **Key risk:** Breaking parsing for users until server-side prompts are updated.

##### T5: Integration verification & cleanup
- **Phase:** 3 | **Parallel:** no | **Est:** 0.3d | **Depends:** T4 | **Complexity:** simple
- **What:** Verify full flow with mock AI responses. Final code cleanup.
- **Key files:** `lib/providers/chat_provider.dart`
- **PRD requirements:** NFR-1
- **Key risk:** None.

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Prompt Sync | High | Medium | Record parsing fails | Use robust fallbacks (ID 1) and log errors clearly during the transition. |
| Circular Dependency | Medium | Low | App crash at init | Use `ChangeNotifierProxyProvider` in `main.dart` to manage the relationship. |

## Dependencies
- `RecordProvider` (for context data).
- `Category` model.

## Success Criteria (Technical)
| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| Context Injection | Payload check | strings present | `debugPrint` the request body |
| Logic Removal | LOC reduction | -20 lines | Count removed string-match code |
| Parsing Accuracy | ID Match rate | 100% | Unit test with mock JSON |

## Tasks Created
| #   | Task                         | Phase | Parallel | Est. | Depends On | Status |
| --- | ---------------------------- | ----- | -------- | ---- | ---------- | ------ |
| 001 | Service Formatting Helpers   | 1     | yes      | 0.3d | —          | closed |
| 002 | Update streamChat Interface  | 1     | no       | 0.3d | 001        | closed |
| 010 | Integrate Providers          | 2     | no       | 0.4d | 002        | closed |
| 020 | Refactor AI Parser           | 3     | no       | 0.7d | 010        | closed |
| 090 | Integration verification     | 3     | no       | 0.3d | all        | closed |

### Summary
- **Total tasks:** 5
- **Parallel tasks:** 1 (T001)
- **Sequential tasks:** 4
- **Estimated total effort:** 2.0d
- **Critical path:** T001 → T002 → T010 → T020 → T090 (~1.7d)

### Dependency Graph
```
  T001 ──→ T002 ──→ T010 ──→ T020 ──→ T090
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: [name]    | T001       | ✅ Covered |
| FR-2: [name]    | T002       | ✅ Covered |
| FR-3: [name]    | T010       | ✅ Covered |
| FR-4: [name]    | T020       | ✅ Covered |
| FR-5: [name]    | T020       | ✅ Covered |
| NFR-1: [name]   | T020, T090 | ✅ Covered |
