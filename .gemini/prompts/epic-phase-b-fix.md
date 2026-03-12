# INTEGRATION FIX MODE — Phase B

You are fixing integration test failures for epic `{epic_name}`.

## Context

- Phase A report: `.gemini/context/verify/epic-reports/{report_file}`
- Test output: See the verification output above
- Iteration: {iteration}/{max_iterations}

## Rules

Follow these rules strictly when fixing integration issues:

### 1. Identify Root Cause
- Which test failed? Which tier (Smoke/Integration/Regression)?
- Which module(s) are involved?
- Is this an interface mismatch, missing implementation, or regression?

### 2. Fix Consumer Side First
- When two modules don't match → check `.gemini/context/active-interfaces.md`
- Fix the **consumer** (caller), not the provider (API)
- Only change the provider if the consumer's expectation is correct per spec

### 3. Keep Unit Tests Passing
- After EVERY change, run existing unit tests for affected modules
- If a unit test breaks, fix it BEFORE moving on
- Never disable or skip existing tests

### 4. Update Interfaces When Changed
- If you change any interface (API, function signature, data format):
  1. Update `.gemini/context/active-interfaces.md` with the new interface
  2. `grep` ALL consumers of that interface across the codebase
  3. Update every consumer to match the new interface

### 5. Record Every Fix
- Add an entry to `.gemini/context/known-issues.md`:
  ```markdown
  ## Fix: {brief description}
  - **Date**: {timestamp}
  - **Issue**: Integration test failure in {test_name}
  - **Root cause**: {description}
  - **Fix applied**: {what you changed}
  - **Files modified**: {list}
  ```

### 6. Commit After Each Fix
- Commit format: `Issue #{issue}: Fix {what} — {tier} test`
- Small, atomic commits — one fix per commit
- Run the failing test again after each fix to verify

## Strategy

1. Read the test output carefully — focus on the FIRST failure
2. Trace the failure to the root cause
3. Apply the minimal fix
4. Verify the fix resolves the test
5. Move to the next failure
6. Repeat until all tests pass or you hit a blocker

## When Blocked

If you cannot fix an issue after 3 attempts:
1. Document the blocker in `.gemini/context/known-issues.md`
2. Move to the next failure
3. The Ralph hook will track overall progress
