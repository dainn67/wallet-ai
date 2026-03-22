---
name: pm-epic-verify-b
description: Epic Verify — Phase B: Integration Verification
# tier: heavy
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
   test -d .claude/epics/$EPIC_NAME || echo "❌ Epic '$EPIC_NAME' not found. Run: /pm:prd-parse $EPIC_NAME"
   ```

2. Check Phase A report exists (required before Phase B):
   ```bash
   REPORT=$(ls -t .claude/context/verify/epic-reports/${ARGUMENTS}-*.md 2>/dev/null | head -1)
   if [ -z "$REPORT" ]; then
     echo "❌ No Phase A report found for epic '$EPIC_NAME'."
     echo "   Run: /pm:epic-verify-a $EPIC_NAME first"
     exit 1
   fi
   ```

3. Check config:
   ```bash
   if [ -f .claude/config/epic-verify.json ]; then
     PHASE_B_ENABLED=$(python3 -c "import json; c=json.load(open('.claude/config/epic-verify.json')); print(c.get('phase_b',{}).get('enabled',True))" 2>/dev/null)
     REQUIRE_A=$(python3 -c "import json; c=json.load(open('.claude/config/epic-verify.json')); print(c.get('phase_b',{}).get('require_phase_a',True))" 2>/dev/null)
   fi
   ```
   If disabled: "❌ Phase B is disabled in config."

4. Check epic-verify.sh exists:
   ```bash
   test -f .claude/context/verify/epic-verify.sh || echo "❌ epic-verify.sh not found"
   ```

## Instructions

### 1. Read Phase A Report

```bash
EPIC_NAME="$EPIC_NAME"
REPORT=$(ls -t .claude/context/verify/epic-reports/${EPIC_NAME}-*.md 2>/dev/null | head -1)
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

1. Read the prompt template from `.claude/prompts/epic-phase-b-write-tests.md`
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
bash .claude/scripts/pm/lifecycle-helpers.sh init-epic-verify-state "$EPIC_NAME" "$REPORT"
```

This activates the Ralph hook (`hooks/stop-epic-verify.sh`) which will enforce the fix loop.

### 5. Run Initial Verification

```bash
bash .claude/context/verify/epic-verify.sh "$EPIC_NAME"
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
Next: /pm:epic-merge {epic_name}
```
Clear the epic state:
```bash
bash .claude/scripts/pm/lifecycle-helpers.sh write-epic-verify-state '{"active_epic": null}'
```

**If EPIC_VERIFY_FAIL or EPIC_VERIFY_PARTIAL:**

1. Read the fix prompt from `.claude/prompts/epic-phase-b-fix.md`
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

To abort: /pm:epic-verify-abort $EPIC_NAME
To check status: /pm:epic-verify-status $EPIC_NAME
```

### 8. QA Agent Tier

Run QA agent verification after standard Phase B tiers complete.

1. Detect QA agents:
   ```bash
   QA_AGENTS=$(bash scripts/qa/detect-agents.sh 2>/dev/null || echo "")
   ```

2. If no agents detected (empty output):
   - Display: `ℹ️ No QA agents detected — skipping QA tier`
   - Append to verify report:
     ```
     ## QA Agent Results
     **Status:** SKIP
     **Reason:** No QA agents detected
     ```
   - Continue to next step

3. If agents detected:

   a. Read epic task files to extract acceptance criteria text:
      ```bash
      AC_TEXT=""
      for task_file in .claude/epics/${EPIC_NAME}/[0-9]*.md; do
        AC_TEXT+=$(grep -A 50 "## Acceptance Criteria" "$task_file" 2>/dev/null | head -50)
        AC_TEXT+="
---
"
      done
      ```

   b. Get changed screens via diff-detect:
      ```bash
      DIFF_OUTPUT=$(bash scripts/qa/diff-detect.sh 2>/dev/null || echo "")
      ```

   c. Read prompt template and spawn subagent:
      - Read `.claude/prompts/qa-agent-prompt.md` if it exists; otherwise use inline instructions
      - Spawn Agent with context: EPIC_NAME, QA_AGENTS list, AC_TEXT, DIFF_OUTPUT
      - Agent prompt must instruct: run QA scenarios, return health score and per-scenario pass/fail
      - If simulator not available, Agent should return: "SKIPPED — no iOS simulator detected"

   d. Capture subagent output and write report section:

      The Agent must return a JSON object. Parse it and append to the report:

      ```bash
      REPORT_FILE=$(ls -t .claude/context/verify/epic-reports/${EPIC_NAME}-*.md 2>/dev/null | head -1)
      ```

      Parse the Agent JSON response (expected fields: `status`, `health_score`, `scenarios_generated`, `scenarios_passed`, `scenarios_failed`, `details`, `skip_reason`):

      ```python
      import json, sys
      try:
          result = json.loads(AGENT_OUTPUT)
          status = result.get("status", "FAIL")
          health_score = result.get("health_score", 0)
          generated = result.get("scenarios_generated", 0)
          passed = result.get("scenarios_passed", 0)
          failed = result.get("scenarios_failed", 0)
          details = result.get("details", [])
          skip_reason = result.get("skip_reason", "")
      except (json.JSONDecodeError, ValueError):
          status = "FAIL"
          health_score = 0
          details = []
          skip_reason = "Could not parse QA agent results"
      ```

      Build and append the `## QA Agent Results` section:

      - If `status == "SKIP"`:
        ```
        \n## QA Agent Results\n**Status:** SKIP\n**Reason:** {skip_reason}
        ```

      - If `status == "PASS"` or `status == "FAIL"`:
        ```
        \n## QA Agent Results\n**Status:** {PASS|FAIL}\n**Health Score:** {health_score}/100\n**Scenarios:** {generated} generated, {passed} passed, {failed} failed\n\n| Scenario | Status | Notes |\n|----------|--------|-------|\n| {name} | {PASS/FAIL} | {notes} |\n...
        ```
        Each entry in `details` is one table row: `name`, `status` (PASS/FAIL), `notes` fields.

      - If JSON was malformed:
        ```
        \n## QA Agent Results\n**Status:** FAIL\n**Reason:** Could not parse QA agent results
        ```

      Append logic:
      ```bash
      if [ -n "$REPORT_FILE" ]; then
        printf '\n%s' "$QA_SECTION" >> "$REPORT_FILE"
      else
        # Edge case: no report file — create one with just the QA section
        mkdir -p .claude/context/verify/epic-reports
        REPORT_FILE=".claude/context/verify/epic-reports/${EPIC_NAME}-qa-$(date -u +%Y%m%d%H%M%S).md"
        printf '%s' "$QA_SECTION" > "$REPORT_FILE"
      fi
      ```

      Display summary:
      - PASS: `✅ QA Agent: PASS — Health Score {score}/100 ({passed}/{generated} scenarios passed)`
      - FAIL: `❌ QA Agent: FAIL — Health Score {score}/100 ({failed} scenarios failed)`
      - SKIP: `⚠️ QA Agent: SKIPPED — {skip_reason}`

4. Error handling — wrap the entire QA Agent Tier in error handling:
   - On any failure (script error, Agent tool error, timeout): append to report with `**Status:** FAIL` and reason
   - **Never set FAIL=1 or modify epic-verify exit code** based on QA results — QA tier is non-blocking

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
