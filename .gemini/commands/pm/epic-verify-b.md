---
model: opus
allowed-tools: Bash, Read, Write, Glob, Edit
---

# Epic Verify — Phase B: Integration Verification

Run Phase B Integration Verification for an epic. Initializes the Ralph loop, writes tests if missing, and runs the 4-tier test runner.

## Usage
```
/pm:epic-verify-b <epic-name>
```

## Quick Check

Do not bother the user with preflight checks progress. Just do them silently.

1. Check epic exists:
   ```bash
   test -d .gemini/epics/$ARGUMENTS || echo "❌ Epic '$ARGUMENTS' not found. Run: /pm:prd-parse $ARGUMENTS"
   ```

2. Check Phase A report exists (required before Phase B):
   ```bash
   REPORT=$(ls -t .gemini/context/verify/epic-reports/${ARGUMENTS}-*.md 2>/dev/null | head -1)
   if [ -z "$REPORT" ]; then
     echo "❌ No Phase A report found for epic '$ARGUMENTS'."
     echo "   Run: /pm:epic-verify-a $ARGUMENTS first"
     exit 1
   fi
   ```

3. Check config:
   ```bash
   if [ -f .gemini/config/epic-verify.json ]; then
     PHASE_B_ENABLED=$(python3 -c "import json; c=json.load(open('.gemini/config/epic-verify.json')); print(c.get('phase_b',{}).get('enabled',True))" 2>/dev/null)
     REQUIRE_A=$(python3 -c "import json; c=json.load(open('.gemini/config/epic-verify.json')); print(c.get('phase_b',{}).get('require_phase_a',True))" 2>/dev/null)
   fi
   ```
   If disabled: "❌ Phase B is disabled in config."

4. Check epic-verify.sh exists:
   ```bash
   test -f .gemini/context/verify/epic-verify.sh || echo "❌ epic-verify.sh not found"
   ```

## Instructions

### 1. Read Phase A Report

```bash
EPIC_NAME="$ARGUMENTS"
REPORT=$(ls -t .gemini/context/verify/epic-reports/${EPIC_NAME}-*.md 2>/dev/null | head -1)
```

Read the report file. Extract:
- **Overall Assessment** (EPIC_READY / EPIC_GAPS / EPIC_NOT_READY)
- **"Phase B Preparation"** section — contains test scenarios and integration points

If assessment is `EPIC_NOT_READY`:
```
❌ Phase A assessment is EPIC_NOT_READY. Cannot proceed to Phase B.
   Fix gaps first: /pm:epic-gaps $EPIC_NAME
```
Stop execution.

### 2. Check Test Directories

```bash
SMOKE_DIR="tests/e2e/epic_${EPIC_NAME}"
INTEG_DIR="tests/integration/epic_${EPIC_NAME}"
HAS_TESTS=false

if [ -d "$SMOKE_DIR" ] || [ -d "$INTEG_DIR" ]; then
  HAS_TESTS=true
fi
```

### 3. Write Tests If Missing

If `$HAS_TESTS` is false:

1. Read the prompt template from `.gemini/prompts/epic-phase-b-write-tests.md`
2. Replace placeholders:
   - `{epic_name}` → the epic name
   - `{report_file}` → basename of the Phase A report
   - `{issue}` → current issue number (if available, otherwise omit)
3. Follow the prompt instructions to write smoke + integration tests
4. Create the test directories and test files
5. Commit the tests:
   ```bash
   git add tests/e2e/epic_${EPIC_NAME}/ tests/integration/epic_${EPIC_NAME}/ 2>/dev/null
   git commit -m "Phase B: Write smoke + integration tests for epic ${EPIC_NAME}"
   ```

### 4. Initialize Epic State

Initialize the Ralph loop state via lifecycle helpers:

```bash
bash .gemini/scripts/pm/lifecycle-helpers.sh init-epic-verify-state "$EPIC_NAME" "$REPORT"
```

This activates the Ralph hook (`hooks/stop-epic-verify.sh`) which will enforce the fix loop.

### 5. Run Initial Verification

```bash
bash .gemini/context/verify/epic-verify.sh "$EPIC_NAME"
```

Capture and display the output.

### 6. Show Results & Instructions

```
═══ Phase B Integration Verification ═══

Epic: {epic_name}
Phase A Report: {report_file}
Phase A Assessment: {assessment}

Test Suites:
  Smoke:       tests/e2e/epic_{name}/     ({exists/created})
  Integration: tests/integration/epic_{name}/ ({exists/created})

Initial Run Result: EPIC_VERIFY_PASS / EPIC_VERIFY_FAIL / EPIC_VERIFY_PARTIAL

Ralph Loop: ✅ Active (max {max_iter} iterations, mid-clear at {mid_clear})
```

### 7. Handle Results

**If EPIC_VERIFY_PASS:**
```
✅ All integration tests passed on first run!

Phase B complete. Ready for Phase C.
Next: /pm:epic-merge {epic_name} then /pm:epic-close {epic_name}
```
Clear the epic state:
```bash
bash .gemini/scripts/pm/lifecycle-helpers.sh write-epic-verify-state '{"active_epic": null}'
```

**If EPIC_VERIFY_FAIL or EPIC_VERIFY_PARTIAL:**

1. Read the fix prompt from `.gemini/prompts/epic-phase-b-fix.md`
2. Replace placeholders:
   - `{epic_name}` → the epic name
   - `{report_file}` → basename of the Phase A report
   - `{iteration}` → 1
   - `{max_iterations}` → from config (default 30)
   - `{issue}` → current issue number
3. Follow the fix prompt to address the failing tests
4. After fixes, the Ralph hook will automatically re-run verification when you try to exit

Display:
```
❌ Integration tests have failures.

Phase B fix loop is now active. The Ralph hook will:
  - Block exit until tests pass (STRICT mode)
  - Re-run verification on each exit attempt
  - Clear context at iteration {mid_clear} if still failing

Fix the issues above, then try to exit. The hook will verify automatically.

To abort: /pm:epic-verify-abort $ARGUMENTS
To check status: /pm:epic-verify-status $ARGUMENTS
```

## Error Handling

- Phase A report missing → "❌ Run /pm:epic-verify-a first"
- epic-verify.sh missing → "❌ epic-verify.sh not found. Check installation."
- lifecycle-helpers.sh missing → "❌ lifecycle-helpers.sh not found"
- Test write fails → Report error, continue with partial tests

## Important Notes

- Phase B REQUIRES Phase A to have run first
- The Ralph hook is activated by `epic-state.json` — do NOT manually edit this file
- Tests should use real assertions, no mocking
- Previous Phase A report is the source of truth for what to test
