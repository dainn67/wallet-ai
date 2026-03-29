---
name: Final audit — flutter analyze, line counts, smoke test
status: closed
created: 2026-03-28T17:50:49Z
updated: 2026-03-28T18:34:13Z
complexity: simple
recommended_model: sonnet
phase: 3
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/144"
depends_on: [006, 007]
parallel: false
conflicts_with: []
files:
  - lib/
prd_requirements:
  - FR-1
  - FR-2
  - FR-3
  - FR-4
  - FR-5
  - FR-6
  - NFR-1
  - NFR-2
  - NFR-3
---

# Final audit — flutter analyze, line counts, smoke test

## Context

After all structural changes are complete (T1-T7), this task runs the full verification suite to confirm zero regressions, all PRD requirements met, and all success criteria passing. This is the quality gate before the epic can be marked complete.

## Description

Run `flutter analyze`, check file line counts, verify no repository imports in UI layer, and perform a full manual walkthrough of all app features. Document any issues found and fix them before completing.

## Acceptance Criteria

- [ ] **FR-1 / Verification:** `grep -r "import.*repositories" lib/screens/ lib/components/` returns 0 results
- [ ] **FR-2 / Verification:** Manual audit of all build() methods — no inline business logic (filtering, aggregation, validation)
- [ ] **FR-3 / Verification:** `grep "fetchData" lib/providers/` returns 0 results; no duplicate methods in providers
- [ ] **FR-4 / Verification:** All provider error handling follows debugPrint pattern; all imports follow AD-4 convention
- [ ] **FR-5 / Verification:** All barrel files match directory contents; no misplaced files
- [ ] **FR-6 / Verification:** Full manual walkthrough passes with no regressions
- [ ] **NFR-1 / Zero regressions:** Every feature works identically to pre-refactor
- [ ] **NFR-2 / Startup time:** `flutter run --profile` time-to-first-frame within ±10% of baseline
- [ ] **NFR-3 / Line counts:** No file exceeds 400 lines; `record_repository.dart` is the only file expected to be close (~513 lines — this exceeds the threshold but is deferred per epic Deferred section)

## Implementation Steps

### Step 1: Static analysis

- Run `flutter analyze` — must return 0 issues
- If issues found → fix each one before proceeding

### Step 2: Automated checks

Run these commands and verify results:
- `grep -r "import.*repositories" lib/screens/ lib/components/` → expect empty (FR-1)
- `grep -r "fetchData" lib/providers/` → expect empty (FR-3)
- `grep -rn "'\.\./\.\." lib/` → expect empty or barrel-only (FR-4/AD-4)
- `wc -l lib/**/*.dart | sort -rn | head -10` → expect no file >400 lines except record_repository.dart (NFR-3)

### Step 3: Manual barrel file audit

For each barrel file, verify exports match directory:
```bash
# Example for helpers
diff <(grep "export" lib/helpers/helpers.dart | sed "s/export '//;s/';//" | sort) <(ls lib/helpers/*.dart | grep -v helpers.dart | xargs -n1 basename | sort)
```

### Step 4: Manual code review

Quick scan of each file category:
- **Providers:** No direct repo imports in chat_provider. CRUD methods use _performOperation or consistent pattern. No duplicate methods.
- **Screens/Tabs:** No .where/.fold/.filter in build() methods. No date manipulation logic. No inline dialogs.
- **Components:** No direct repo imports. Components read providers via Consumer/Provider.of only.

### Step 5: Full manual walkthrough

Test every feature:
1. **Chat tab:** Send a message → AI responds → records created → records visible in bubble with edit button
2. **Edit from chat:** Tap edit on chat record → popup opens → change amount → save → record updated in chat and records tab
3. **Records tab:** Verify totals (income, expense, balance) are correct. Edit a record → changes saved. Delete a record → removed.
4. **Categories tab:** Navigate months → totals change. Add category → appears. Edit category → name updated. Delete category → records moved to Uncategorized. Add sub-category → appears under parent.
5. **Drawer:** Switch language → labels change. Change currency → confirmation dialog → data reset. Reset all data → confirmation → data cleared.
6. **Home widget:** Verify widget data updates after record operations.

### Step 6: Performance baseline (if applicable)

- If a pre-refactor baseline was captured: run `flutter run --profile` and compare time-to-first-frame
- If no baseline: note current time for future reference

## Technical Details

- **Approach:** Systematic verification of all PRD success criteria
- **Files:** All `lib/` files (read-only audit)
- **Edge cases:**
  - `record_repository.dart` at 513 lines exceeds NFR-3's 400-line threshold — this was identified during epic planning and deferred to a separate initiative (repository splitting). Document this exception.

## Tests to Write

### Unit Tests
- No new tests — this task verifies existing behavior

## Verification Checklist

- [ ] `flutter analyze` — 0 issues
- [ ] FR-1 grep — 0 repository imports in UI
- [ ] FR-3 grep — fetchData removed
- [ ] FR-4 — no multi-level relative imports
- [ ] NFR-3 — line counts checked
- [ ] Barrel files — all match directories
- [ ] Manual walkthrough — all 6 feature areas pass
- [ ] All findings documented (any exceptions noted)

## Dependencies

- **Blocked by:** T6, T7 (all changes must be complete)
- **Blocks:** None — this is the final task
- **External:** None
