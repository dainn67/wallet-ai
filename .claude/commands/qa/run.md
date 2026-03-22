---
allowed-tools: [Read, Write, Bash, Glob, Grep, Edit]
---

# QA: Run

Orchestrate the full QA pipeline: discover scenarios, parse steps, setup simulator, execute steps via shell wrappers, evaluate UI state (Claude Code as LLM-as-judge), compute health score, and generate markdown report.

## Usage
```
/qa:run                      # Run all scenarios
/qa:run quiz-flow            # Run only named scenario
/qa:run --diff-aware         # Run only scenarios for screens changed in git diff
/qa:run --diff-aware quiz    # Diff-aware + name filter (intersection)
```

## Quick Check

1. Load config:
   ```bash
   if [ -f config/qa.json ]; then
     cat config/qa.json
   else
     echo '{"enabled":true,"default_timeout":300,"health_score_threshold":70,"category_weights":{"ui_layout":25,"navigation_flow":25,"data_display":25,"accessibility":25},"evidence_retention_runs":10}'
   fi
   ```
   If config missing, use hardcoded defaults and warn: `"⚠️ config/qa.json not found, using defaults"`

2. Check scenario directory:
   ```bash
   test -d .claude/qa/scenarios || echo "❌ No scenarios: .claude/qa/scenarios/ not found. Run: /qa:scenario-new"
   ```

3. Ensure output directories:
   ```bash
   mkdir -p .claude/qa/reports .claude/qa/evidence 2>/dev/null
   ```

## Instructions

Execute all 7 phases sequentially. Track start time for duration calculation.

```bash
QA_START=$(date +%s)
RUN_ID=$(date -u +"%Y%m%d-%H%M%S")
```

### Phase 1 — Discover

**Check for `--diff-aware` flag** in `$ARGUMENTS`:
```bash
DIFF_AWARE=false
NAME_FILTER=""
if echo "${ARGUMENTS:-}" | grep -q -- '--diff-aware'; then
  DIFF_AWARE=true
  NAME_FILTER=$(echo "${ARGUMENTS:-}" | sed 's/--diff-aware//g' | xargs)
else
  NAME_FILTER="${ARGUMENTS:-}"
fi
```

**If `--diff-aware` is set**, use diff detection to get filtered scenario list:
```bash
source scripts/qa/diff-detect.sh
DIFF_RESULT=$(detect_and_filter)
# Parse scenario list from DIFF_RESULT["data"]["scenarios"]
# Note whether fallback was triggered (run all) and log accordingly:
#   Fallback: "Diff-aware: no screen changes detected — running all N scenarios"
#   Filtered: "Diff-aware: {M}/{N} scenarios selected based on changed files"
```
Use the returned scenario list as the candidate set for further filtering.

**If `--diff-aware` is NOT set**, find all scenario files:
```bash
ls .claude/qa/scenarios/*.md 2>/dev/null
```

If `$NAME_FILTER` is non-empty, apply name filter to the candidate set:
```bash
# Filter candidate scenarios to those matching NAME_FILTER in filename
```

- If no scenarios found: print `"❌ No scenarios found in .claude/qa/scenarios/"` and stop.
- If name filter specified and no match: print `"❌ Scenario '${NAME_FILTER}' not found"` and stop.
- Print: `"Found {N} scenario(s): {list}"`

### Phase 2 — Parse

For each discovered scenario file:

1. Read the file content.
2. Extract YAML frontmatter fields: `name`, `screens`, `priority`, `categories`.
3. Parse numbered steps (lines matching `^\d+\.`).
4. For each step, decompose into action + assertion:
   - Split at ` → ` (arrow with spaces) to get `action_part` and `assertion_part`.
   - If no arrow, the entire line is both action and assertion.
   - Detect action keyword from action_part:
     - Vietnamese: `mở`/`launch`/`open` → `launch`, `chọn`/`select`/`tap` → `tap`, `kiểm tra`/`verify`/`check` → `verify`, `vuốt`/`swipe` → `swipe`, `type` → `type`
     - Default → `verify` (if no action keyword detected, treat as verify-only step)
   - Extract quoted element labels: text within single quotes `'...'`.
   - Build step object: `{action, target, assertion, raw_text}`

If a scenario fails to parse (no steps, invalid format): log `"⚠️ Skipping {name}: parse error"` and continue.

### Phase 3 — Setup

Verify simulator is ready:
```bash
source scripts/qa/simctl-wrapper.sh
simctl_auto_detect
```

Parse the JSON response. If `success` is false: print the error and ask user to boot a simulator manually.

Store the UDID from the response for use in subsequent phases.

Verify the simulator is responding by running a quick describe-ui:
```bash
source scripts/qa/axe-wrapper.sh
axe_describe_ui "$UDID"
```

If this fails, print error and stop.

### Phase 4 — Execute

For each scenario, for each parsed step:

1. **Source wrappers:**
   ```bash
   source scripts/qa/evidence-capture.sh
   ```

2. **Execute based on action type:**
   - `launch`: No shell action needed (app should already be running). Capture current state.
   - `tap`: Call `capture_before_after "$RUN_ID" "$STEP_N" "tap" "$TARGET" "$UDID"`
   - `type`: Call `capture_before_after "$RUN_ID" "$STEP_N" "type" "$TEXT" "$UDID"`
   - `swipe`: Call `capture_before_after "$RUN_ID" "$STEP_N" "swipe" "$DIRECTION" "$UDID"`
   - `verify`: No action — capture state only: `capture_step_evidence "$RUN_ID" "$STEP_N" "axe" "$UDID"`

3. **Collect evidence paths** from the JSON response for Phase 5.

4. **Handle errors:** If the shell wrapper returns `{"success": false}`, mark the step as FAIL with the error message. Do NOT stop — continue to next step.

### Phase 5 — Evaluate

For each step, evaluate using **dual signal** (accessibility tree + screenshot):

1. **Read the accessibility tree JSON file** from the evidence directory:
   - For action steps: read `after-accessibility-tree.json`
   - For verify-only steps: read `accessibility-tree.json`

2. **Read the screenshot file** from the evidence directory:
   - For action steps: read `after-screenshot.png`
   - For verify-only steps: read `screenshot.png`

3. **Evaluate the assertion** by analyzing BOTH signals:
   - Parse the assertion text to understand what should be true.
   - Check the accessibility tree JSON for expected elements, labels, and states.
   - Examine the screenshot visually for UI correctness.
   - Consider both signals together — they should corroborate.

4. **Produce verdict:**
   ```
   result: PASS | FAIL | UNCERTAIN
   confidence: 0-100
   reasoning: brief explanation of why this verdict was reached
   ```

   Guidelines for evaluation:
   - **PASS** (confidence >= 60): Both accessibility tree AND visual confirm the assertion.
   - **FAIL** (confidence >= 60): Clear evidence that the assertion does NOT hold.
   - **UNCERTAIN** (confidence < 60): Ambiguous evidence or conflicting signals between tree and screenshot.

5. **For steps where shell wrapper returned error:** Mark as FAIL with confidence 100 and reason = the error message.

### Phase 6 — Score

Compute health score using category weights from config:

1. **Group steps by category** from each scenario's frontmatter `categories` field.
   - A step belongs to ALL categories listed in its scenario's frontmatter.
   - If a scenario has `categories: [ui_layout, navigation_flow]`, every step in that scenario counts toward both categories.

2. **Per-category score:**
   ```
   category_score = (passing_steps_in_category / total_steps_in_category) * 100
   ```

3. **Overall health score:**
   - Only include categories that have at least one step (don't penalize empty categories).
   - Weight using `category_weights` from config (default: 25% each).
   - Normalize weights to sum to 100% across active categories only.
   ```
   active_weight_sum = sum of weights for categories with steps
   health_score = sum(category_score * weight / active_weight_sum) for each active category
   ```

4. Round to nearest integer.

### Phase 7 — Report

Calculate duration:
```bash
QA_END=$(date +%s)
DURATION=$((QA_END - QA_START))
```

Write markdown report to `.claude/qa/reports/${RUN_ID}.md`:

```markdown
# QA Report: {RUN_ID}
**Health Score: {score}/100** | {pass_count}/{total_count} steps passed
Categories: UI Layout {score}% | Navigation {score}% | Data {score}% | A11y {score}%
Generated: {ISO timestamp} | Duration: {DURATION}s
Diff-aware: {M}/{N} scenarios selected based on changed files | OR | Diff-aware: disabled
---
## Per-Scenario Results
### {scenario-name} — {PASS|FAIL}
A scenario is PASS only if ALL steps passed.

| Step | Action | Result | Confidence | Details |
|------|--------|--------|------------|---------|
| 1 | {action description} | {PASS/FAIL/UNCERTAIN} | {N}% | {reasoning} |

## Accessibility Findings
List any accessibility-specific findings from evaluation:
- Elements missing accessibility labels
- Poor contrast or layout issues detected
- Tab order / focus order problems
If no accessibility issues found: "No accessibility issues detected."

## Recommendations
Based on failures, provide actionable recommendations:
- Specific elements that need fixing
- Missing UI states
- Suggested improvements
If all passed: "All scenarios passed. No recommendations."
```

Print summary:
```
✅ QA run complete: {RUN_ID}
   Health Score: {score}/100
   Passed: {pass_count}/{total_count} steps
   Report: .claude/qa/reports/{RUN_ID}.md
   Duration: {DURATION}s
```

## Edge Cases

- **No scenarios found** → `"❌ No scenarios in .claude/qa/scenarios/"`
- **Scenario parse failure** → skip with `⚠️`, continue others
- **Shell wrapper error** → mark step FAIL with error details, continue
- **All steps UNCERTAIN** → flag scenario for human review in report
- **Config missing** → use hardcoded defaults, warn once
- **Evidence directory creation fails** → continue without evidence, note in report
- **Simulator not booted** → try auto-detect first, then ask user
