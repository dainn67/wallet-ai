<!-- Source: GitHub Issues API | Collected: 2026-03-12T07:46:45Z | Epic: setup-provider -->

# Issue Descriptions

## Issue #1: Epic: setup-provider


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


---

## Issue #2: Install Provider Dependency


## Context
The project requires the `provider` package to implement scalable state management. This task covers the initial installation and verification of the dependency.

## Description
Add the `provider` package to the `pubspec.yaml` file and ensure all dependencies are correctly resolved. This is the foundation for all subsequent state management tasks.

## Acceptance Criteria
- [ ] **FR-1 / Happy path:** `provider` package is added to `pubspec.yaml` and dependencies are resolved successfully.
- [ ] **FR-1 / Scenario:** Running `flutter pub get` completes without errors.

## Implementation Steps
### Step 1: Update pubspec.yaml
- Modify `pubspec.yaml` to include `provider: ^6.1.2` (or latest stable) under `dependencies`.
- Ensure proper indentation.

### Step 2: Resolve dependencies
- Run `flutter pub get` in the terminal.
- Verify that `pubspec.lock` is updated and no version conflicts occur.

## Technical Approach
- **Approach:** Standard Flutter package installation.
- **Files to create/modify:** `pubspec.yaml` (add dependency).
- **Patterns to follow:** Official Flutter dependency management.

## Tests to Write
### Unit Tests
- N/A for package installation. Verification is done via the CLI.

## Verification Checklist
- [ ] Check pubspec: `grep provider pubspec.yaml`
- [ ] Verify resolution: `flutter pub get`
- [ ] Build check: `flutter build bundle` (or similar lightweight check)

## Dependencies
- **Blocked by:** None
- **Blocks:** 010
- **External:** pub.dev

---

## Issue #3: Create CounterProvider


## Context
This task establishes the project structure for providers and implements a sample provider to verify the state management pattern.

## Description
Create the `lib/providers/` directory and implement the `CounterProvider` class using `ChangeNotifier`. This provider will replace the local state in the default counter app.

## Acceptance Criteria
- [ ] **FR-2 / Happy path:** `lib/providers/` directory is created.
- [ ] **FR-4 / Happy path:** `CounterProvider` class implements `ChangeNotifier` and has an `int _count` variable and an `increment()` method.
- [ ] **FR-4 / Scenario:** `notifyListeners()` is called inside `increment()`.

## Implementation Steps
### Step 1: Create directory
- Create the directory `lib/providers/`.

### Step 2: Implement CounterProvider
- Create `lib/providers/counter_provider.dart`.
- Define `class CounterProvider extends ChangeNotifier`.
- Add private field `int _count = 0` and getter `int get count => _count`.
- Add method `void increment() { _count++; notifyListeners(); }`.

## Interface Contract
### Receives from 001:
- The project has `provider` package available in the environment.

### Produces for 020:
- File: `lib/providers/counter_provider.dart`
  - Export: `CounterProvider` class.
  - Guaranteed: Provides an integer state and a way to increment it with change notifications.

## Technical Approach
- **Approach:** Idiomatic `ChangeNotifier` pattern for state management.
- **Files to create/modify:** `lib/providers/counter_provider.dart` (new file).
- **Patterns to follow:** See `provider` package documentation for `ChangeNotifierProvider` examples.

## Tests to Write
### Unit Tests
- `test/providers/counter_provider_test.dart`
  - Test: Initial count is 0.
  - Test: `increment()` increases count by 1 and notifies listeners.

## Verification Checklist
- [ ] File exists: `ls lib/providers/counter_provider.dart`
- [ ] Unit tests pass: `flutter test test/providers/counter_provider_test.dart`

## Dependencies
- **Blocked by:** 001
- **Blocks:** 020
- **External:** None

---

## Issue #4: Integrate MultiProvider and Update UI


## Context
This task integrates the previously created provider into the application's root and updates the UI to consume the global state.

## Description
Configure `MultiProvider` in `lib/main.dart` to provide `CounterProvider` to the widget tree. Refactor `MyHomePage` to use the provider instead of its own local `_counter` state.

## Acceptance Criteria
- [ ] **FR-3 / Happy path:** `MultiProvider` is the parent of `MaterialApp` (or within `MyApp`).
- [ ] **FR-4 / Happy path:** `MyHomePage` displays the counter value from `CounterProvider`.
- [ ] **FR-4 / Scenario:** Clicking the FloatingActionButton triggers `counterProvider.increment()`, and the UI updates.

## Implementation Steps
### Step 1: Configure MultiProvider in main.dart
- Import `package:provider/provider.dart` and `package:wallet_ai/providers/counter_provider.dart`.
- In `main.dart`, wrap `MyApp` or its content in a `MultiProvider`.
- Add `ChangeNotifierProvider(create: (_) => CounterProvider())` to the `providers` list.

### Step 2: Refactor MyHomePage
- Convert `MyHomePage` from `StatefulWidget` to `StatelessWidget`.
- Remove `_MyHomePageState`, `_counter` variable, and `_incrementCounter` method.
- In `build(BuildContext context)`, access the count using `context.watch<CounterProvider>().count`.
- Update the `onPressed` callback of the `FloatingActionButton` to use `context.read<CounterProvider>().increment()`.

## Interface Contract
### Receives from 010:
- File: `lib/providers/counter_provider.dart`
  - Export: `CounterProvider` class.

### Produces for 090:
- A fully functional app using `provider` for state management.

## Technical Approach
- **Approach:** Root-level `MultiProvider` for scalability.
- **Files to create/modify:** `lib/main.dart` (refactor).
- **Patterns to follow:** Use `context.watch` for UI rebuilds and `context.read` for actions.

## Tests to Write
### Widget Tests
- `test/widget_test.dart` (Update existing or add new)
  - Test: App starts with counter 0.
  - Test: Tapping '+' icon increments counter display to 1.

## Verification Checklist
- [ ] Root check: Ensure `MultiProvider` is implemented correctly in `main.dart`.
- [ ] Functional check: Run the app and verify the counter still works.
- [ ] Test check: `flutter test` passes.

## Dependencies
- **Blocked by:** 010
- **Blocks:** 090
- **External:** None

---

## Issue #5: Integration verification & cleanup


# Task: Integration verification & cleanup

## Context
Final quality gate before epic completion. Ensures all tasks integrate correctly and all PRD requirements are met.

## Acceptance Criteria
- [ ] All other tasks in this epic are status: done
- [ ] Full build succeeds with no errors
- [ ] All existing tests pass (no regressions)
- [ ] New tests for this epic all pass
- [ ] **NFR-1 / Scenario:** Code follows Flutter idiomatic patterns.
- [ ] **NFR-2 / Scenario:** No redundant local state remains in the counter implementation.

## Verification
- Run `flutter test` to ensure all tests pass.
- Run `flutter analyze` to check for lint issues.
- Manual verification of the counter app functionality.

## Dependencies
- **Blocked by:** 001, 010, 020
- **Blocks:** None
- **External:** None

---

