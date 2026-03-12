---
name: pm-epic-verify
description: Epic Verify — Full Pipeline Orchestrator
# tier: heavy
---

# Epic Verify — Full Pipeline Orchestrator

Run the full epic verification pipeline: Phase A (Semantic Review) → Developer Review → Phase B (Integration Verification) → Phase C (Final Report + Post-Closure).

## Usage
```
/pm:epic-verify <epic-name>
```

## Quick Check

Do not bother the user with preflight checks progress. Just do them silently.

1. Check epic exists:
   ```bash
   test -d .gemini/epics/$EPIC_NAME || echo "❌ Epic '$EPIC_NAME' not found. Run: /pm:prd-parse $EPIC_NAME"
   ```

2. Check Phase A command exists:
   ```bash
   test -f .gemini/commands/pm/epic-verify-a.md || echo "❌ Phase A command not found"
   ```

3. Check Phase B command exists:
   ```bash
   test -f .gemini/commands/pm/epic-verify-b.md || echo "❌ Phase B command not found"
   ```

4. Check config:
   ```bash
   if [ -f .gemini/config/epic-verify.json ]; then
     python3 -c "import json; c=json.load(open('.gemini/config/epic-verify.json')); print('ok')"
   fi
   ```

5. Create required directories:
   ```bash
   mkdir -p .gemini/context/verify/epic-reports 2>/dev/null
   mkdir -p .gemini/context/epics/.archive 2>/dev/null
   ```

## Instructions

### Phase A: Semantic Review

Execute Phase A by following the instructions in `.gemini/commands/pm/epic-verify-a.md`, using `$EPIC_NAME` as the epic name.

**IMPORTANT:** Do NOT just reference the file — actually read it and execute its full instructions inline. The Phase A command will:
1. Run input assembly
2. Analyze documentation
3. Write report to `.gemini/context/verify/epic-reports/{epic}-{timestamp}.md`
4. Show summary and developer decision (4 options)

### Developer Review Pause

Phase A ends with a developer decision. The 4 options are:

1. **Proceed to Phase B** — Continue to integration tests
2. **Fix gaps first** — Address critical/high gaps before continuing
3. **Accept gaps** — Acknowledge gaps as technical debt, proceed to Phase B
4. **Abort** — Stop verification, continue development

**Wait for the developer's explicit choice before continuing.**

- If **option 1 or 3** → Continue to Phase B below
- If **option 2** → Stop here. Developer will fix gaps and re-run `/pm:epic-verify`
- If **option 4** → Stop here. Display: "Verification aborted. Resume with: /pm:epic-verify $EPIC_NAME"

### Phase B: Integration Verification

Execute Phase B by following the instructions in `.gemini/commands/pm/epic-verify-b.md`, using `$EPIC_NAME` as the epic name.

**IMPORTANT:** Do NOT just reference the file — actually read it and execute its full instructions inline. The Phase B command will:
1. Read Phase A report
2. Write tests if missing
3. Initialize Ralph loop state
4. Run verification
5. Enter fix loop if tests fail

Wait for Phase B to complete (all tests pass or max iterations reached).

### Phase C: Final Report + Post-Closure

After Phase B completes, generate the Final Report and apply closure decisions.

#### Step 1: Gather Data

Find the Phase A report:
```bash
EPIC_NAME="$EPIC_NAME"
PHASE_A_REPORT=$(ls -t .gemini/context/verify/epic-reports/${EPIC_NAME}-*.md 2>/dev/null | grep -v "final" | head -1)
```
If no report found: "❌ No Phase A report found. This should not happen after Phase A completed."

Read the Phase A report file and extract from its frontmatter/content:
- `phase_a_assessment`: The `assessment` field (EPIC_READY / EPIC_GAPS / EPIC_NOT_READY)
- `quality_score`: The `quality_score` field
- Coverage Matrix section (copy for final report)
- Gap Report section (copy for final report)

Read the epic state file for Phase B results:
```bash
cat .gemini/context/verify/epic-state.json
```
Extract from the JSON:
- `phase_b_result`: The exit status (EPIC_VERIFY_PASS / EPIC_VERIFY_FAIL / EPIC_VERIFY_PARTIAL)
- `total_iterations`: Number of iterations completed
- `iterations`: Array of iteration results (for the log)

Get files modified during Phase B from git log:
```bash
git log --oneline --name-only --since="$(python3 -c "import json; d=json.load(open('.gemini/context/verify/epic-state.json')); print(d.get('started',''))" 2>/dev/null)" -- . 2>/dev/null | head -50
```

#### Step 2: Apply Decision Matrix

Determine the `final_decision` by cross-referencing the extracted `phase_a_assessment` and `phase_b_result`:

| Phase A    | Phase B            | → `final_decision`                |
| ---------- | ------------------ | --------------------------------- |
| READY      | PASS               | **EPIC_COMPLETE**                 |
| GAPS       | PASS               | **EPIC_COMPLETE** (accepted gaps) |
| READY      | PARTIAL            | **EPIC_PARTIAL**                  |
| GAPS       | PARTIAL            | **EPIC_PARTIAL**                  |
| Any        | FAIL               | **EPIC_BLOCKED**                  |
| Any        | BLOCKED (max iter) | **EPIC_BLOCKED**                  |
| NOT_READY  | N/A                | N/A — Phase B should not have run |

Use these three values (`phase_a_assessment`, `phase_b_result`, `final_decision`) in all subsequent steps.

#### Step 3: Generate Final Report

Get current datetime:
```bash
CURRENT_DT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
```

Write report to `.gemini/context/verify/epic-reports/{epic}-final-{timestamp}.md`:

```markdown
---
epic: {epic_name}
phase: final
generated: {CURRENT_DT}
phase_a_assessment: {EPIC_READY/EPIC_GAPS/EPIC_NOT_READY}
phase_b_result: {EPIC_VERIFY_PASS/EPIC_VERIFY_FAIL/EPIC_VERIFY_PARTIAL}
final_decision: {EPIC_COMPLETE/EPIC_PARTIAL/EPIC_BLOCKED}
quality_score: {X}/5
total_iterations: {N}
---

# Epic Verification Final Report: {epic_name}

## Metadata
| Field            | Value                    |
| ---------------- | ------------------------ |
| Epic             | {epic_name}              |
| Phase A Status   | {assessment_emoji}       |
| Phase B Status   | {phase_b_emoji}          |
| Final Decision   | {decision}               |
| Quality Score    | {X}/5                    |
| Total Iterations | {N}                      |
| Generated        | {CURRENT_DT}             |

## Coverage Matrix (Final)
Copy the Coverage Matrix from Phase A report. For any gaps that were fixed during Phase B iterations, update their status from ❌ to ✅.

## Gaps Summary

### Fixed in Phase B
List gaps from Phase A's Gap Report that were resolved during Phase B fix iterations. Cross-reference Phase A gaps with Phase B iteration changes.

### Accepted (technical debt)
List gaps the developer explicitly accepted in the Developer Review pause (option 3).

### Unresolved
List any remaining gaps that were not fixed and not accepted.

## Test Results (4 Tiers)
Extract from the last Phase B test run output:
- Smoke tests: pass/fail count
- Integration tests: pass/fail count
- Regression tests: pass/fail count
- Performance tests: pass/fail/skipped count

## Phase B Iteration Log
| Iter | Result | Issues Fixed | Duration |
| ---- | ------ | ------------ | -------- |
Populate from `epic-state.json` → `iterations` array. Each entry has iteration number, result, and changes made.

## New Issues Created
List any GitHub issues created during Phase B fix iterations (check git log for issue references).

## Files Modified During Phase B
List from the git log output gathered in Step 1.
```

#### Step 4: Show Final Summary

```
═══════════════════════════════════════════
  Epic Verification Complete: {epic_name}
═══════════════════════════════════════════

Phase A: {assessment_emoji} {assessment}
Phase B: {phase_b_emoji} {phase_b_result}
Decision: {decision}

Quality Score: {X}/5
Iterations: {N}
Report: .gemini/context/verify/epic-reports/{epic}-final-{timestamp}.md
```

#### Step 5: Post-Closure Actions

Read config to determine which actions to take:
```bash
if [ -f .gemini/config/epic-verify.json ]; then
  eval $(python3 -c "
import json
c=json.load(open('.gemini/config/epic-verify.json')).get('phase_c',{})
print(f'CREATE_TAG={c.get(\"create_git_tag_on_complete\",True)}')
print(f'ARCHIVE={c.get(\"archive_epic_context_on_complete\",True)}')
print(f'AUTO_CLOSE={c.get(\"auto_close_epic_on_complete\",False)}')
print(f'SAVE_BASELINE={c.get(\"save_regression_baseline\",True)}')
")
fi
```

**Only execute post-closure actions if `final_decision` is EPIC_COMPLETE.** If EPIC_PARTIAL or EPIC_BLOCKED, skip directly to the corresponding section below.

**Git Tag** (if `create_git_tag_on_complete` is True):
```bash
git tag "epic-${EPIC_NAME}-verified" -m "Epic verified $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
```
If tag already exists: "⚠️ Tag already exists. Skipping."

**Archive Epic Context** (if `archive_epic_context_on_complete` is True):
```bash
mkdir -p .gemini/context/epics/.archive
if [ -f .gemini/context/epics/${EPIC_NAME}.md ]; then
  mv .gemini/context/epics/${EPIC_NAME}.md .gemini/context/epics/.archive/
fi
```

**Commit Report:**
```bash
git add .gemini/context/verify/epic-reports/
git commit -m "[Epic-Complete] ${EPIC_NAME} — verified and closed"
```

**Close GitHub Issue** (if `auto_close_epic_on_complete` is True):

First, check remote origin per `.gemini/rules/github-operations.md`:
```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm.git"* ]]; then
  echo "❌ ERROR: Attempting to sync with CCPM template repository!"
  echo "Update remote: git remote set-url origin <your-fork-url>"
else
  # Find epic issue number from epic config
  EPIC_ISSUE=$(python3 -c "
import json
with open('.gemini/epics/${EPIC_NAME}/epic.json') as f:
    d = json.load(f)
print(d.get('github_issue', ''))
" 2>/dev/null)

  # Detect repo from epic's github: field
  REPO=""
  epic_github=$(grep '^github:' .gemini/epics/${EPIC_NAME}/epic.md 2>/dev/null | head -1 | sed 's/^github: *//')
  if [ -n "$epic_github" ]; then
    REPO=$(echo "$epic_github" | sed 's|https://github.com/||' | sed 's|/issues/.*||')
  fi
  if [ -z "$REPO" ]; then
    REPO=$(bash .gemini/scripts/pm/github-helpers.sh get-repo-for-issue 2>/dev/null || echo "")
  fi

  if [ -n "$EPIC_ISSUE" ]; then
    gh issue close "$EPIC_ISSUE" --repo "$REPO" -c "Epic verified. See final report at .gemini/context/verify/epic-reports/"
  fi
fi
```

**Save Regression Baseline** (if `save_regression_baseline` is True):
```bash
mkdir -p .gemini/context/verify/baselines
if [ -f .gemini/context/verify/results/latest.json ]; then
  cp .gemini/context/verify/results/latest.json .gemini/context/verify/baselines/${EPIC_NAME}-baseline.json
fi
```

**Clear Ralph loop state:**
```bash
bash .gemini/scripts/pm/lifecycle-helpers.sh write-epic-verify-state '{"active_epic": null}'
```

Display post-closure summary:
```
Post-closure actions:
  Git tag:         {✅ Created / ⏭️ Skipped (config)}
  Archive context: {✅ Archived / ⏭️ Skipped (config)}
  Commit report:   ✅ Committed
  Close issue:     {✅ Closed / ⏭️ Skipped (config)}
  Baseline saved:  {✅ Saved / ⏭️ Skipped (config)}
```

**If decision is EPIC_PARTIAL:**
```
⚠️ Epic is PARTIAL. Developer decision required:
  1. Ship as-is — Accept partial completion
  2. Continue fixing — Resume development
  3. Create follow-up epic — Track remaining work

Choose an option.
```

**If decision is EPIC_BLOCKED:**
```
❌ Epic is BLOCKED. No post-closure actions taken.

Recommended:
  - Review failing tests
  - Check Phase B iteration log in the final report
  - Fix issues and re-run: /pm:epic-verify {epic_name}
```

## Error Handling

- Phase A fails → "❌ Phase A failed: {error}"
- Phase B fails → "❌ Phase B failed: {error}. Check epic-state.json"
- Config missing → Use defaults (tag=true, archive=true, auto_close=false, baseline=true)
- Git tag exists → "⚠️ Tag already exists. Skipping."
- Report write fails → "❌ Cannot write final report: {error}"

## Important Notes

- This command orchestrates Phase A and Phase B — it does NOT duplicate their logic
- Read and execute each phase's command instructions inline
- Always wait for developer decisions at pause points
- Post-closure actions are config-driven — respect `phase_c` settings
- The Final Report is the permanent record of epic verification

## Next Steps (by decision)

- **EPIC_COMPLETE** → `/pm:epic-merge $EPIC_NAME` then `/pm:epic-close $EPIC_NAME`
- **EPIC_PARTIAL** → Developer decides: ship, continue fixing, or create follow-up epic
- **EPIC_BLOCKED** → Fix issues, then `/pm:epic-verify $EPIC_NAME` again
