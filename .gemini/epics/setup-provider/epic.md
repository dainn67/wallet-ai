---
name: setup-provider
status: done
created: 2026-03-12T00:00:00Z
progress: 100%
priority: P0
prd: .gemini/prds/setup-provider.md
task_count: 3
github: https://github.com/dainn67/wallet-ai/issues/1
---

# Epic: setup-provider

## Overview
We will implement the `provider` state management library to replace the local `setState` logic in the default Flutter template. This approach provides a scalable foundation for the `wallet_ai` app, allowing for clean separation of concerns between business logic and UI. We'll use `MultiProvider` at the root to ensure future providers can be added easily without deeply nesting widgets.

## Architecture Decisions
### AD-1: Use Provider for State Management
**Context:** The app needs a way to share state and logic across widgets.
**Decision:** Use the `provider` package.
**Alternatives rejected:** `Riverpod` (too complex for initial MVP), `Bloc` (high boilerplate).
**Trade-off:** Simple to learn and use, but can lead to performance issues if `watch` is overused on large widget trees.
**Reversibility:** Moderate - switching to Riverpod later is possible but requires refactoring.

### AD-2: Root-level MultiProvider
**Context:** Multiple features will eventually need global state (Auth, Wallet, Settings).
**Decision:** Wrap the `MaterialApp` in a `MultiProvider` in `main.dart`.
**Alternatives rejected:** Individual providers wrapped around specific screens (leads to "provider hunting" and nesting).
**Trade-off:** Slightly more global state than strictly necessary, but much cleaner for scaling.
**Reversibility:** Easy.

## Technical Approach
### Provider Layer
Create `lib/providers/` and implement `CounterProvider` extending `ChangeNotifier`.

### UI Integration
Modify `lib/main.dart` to:
1. Import `provider` and the new provider.
2. Wrap `MyApp` or its child in `MultiProvider`.
3. Update `MyHomePage` to use `context.watch<CounterProvider>()` and `context.read<CounterProvider>().increment()`.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Installation | §Technical Approach | T1 | `flutter pub get` check |
| FR-2: Directory | §Technical Approach | T2 | `ls lib/providers/` |
| FR-3: MultiProvider | §Technical Approach | T3 | `main.dart` code review |
| FR-4: Example | §Technical Approach | T2, T3 | Functional test |
| NFR-1: Idiomatic | §Overview | T2, T3 | Lint check |
| NFR-2: Minimal | §Overview | T3 | Code review |

## Tasks Created
| #   | Task                            | Phase | Parallel | Est. | Depends On | Status |
| --- | ------------------------------- | ----- | -------- | ---- | ---------- | ------ |
| 2 | Install Provider Dependency      | 1     | no       | 0.5d | —          | done   |
| 3 | Create CounterProvider           | 2     | yes      | 1d   | 001        | done   |
| 4 | Integrate MultiProvider & UI    | 3     | no       | 1.5d | 010        | done   |
| 5 | Integration verification        | 3     | no       | 0.5d | all        | done   |

### Summary
- **Total tasks:** 4
- **Parallel tasks:** 1 (Phase 2)
- **Sequential tasks:** 3 (Phase 1 + 3)
- **Estimated total effort:** 3.5d
- **Critical path:** T001 → T010 → T020 → T090 (~3.5d)

### Dependency Graph
```
  T001 ──→ T010 ──→ T020 ──→ T090
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: Installation | T001       | ✅ Covered |
| FR-2: Directory    | T010       | ✅ Covered |
| FR-3: MultiProvider| T020       | ✅ Covered |
| FR-4: Example      | T010, T020 | ✅ Covered |
| NFR-1: Idiomatic   | T090       | ✅ Covered |
| NFR-2: Minimal     | T090       | ✅ Covered |

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Provider version conflict | Low | Low | Build fails | Specify stable version in pubspec. |
| Context Misuse | Low | Medium | Runtime error | Ensure provider is accessed below MultiProvider in the tree. |

## Success Criteria (Technical)
| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| Provider installed | Dependency check | `provider` present | `grep provider pubspec.yaml` |
| App scales | MultiProvider usage | Root wrapping | Code review of `main.dart` |
| Counter works | Functional UI | Increment works | Manual test / Widget test |

## Estimated Effort
Total: 3 days. Critical path: T1 -> T2 -> T3.
- Phase 1: 1.5d
- Phase 2: 1.5d
