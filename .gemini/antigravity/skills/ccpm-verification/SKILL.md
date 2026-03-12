---
name: ccpm-verification
description: Use when done, complete, finish, ready to close, close issue, mark complete. NOT for: start, implement, code, write code, epic verify, verify epic.
---

# CCPM Verification

Run the full verification pipeline before closing any task.

## Steps

**SEQUENTIAL — do not skip any step.**

### Step 1 — Run Verification

Run `antigravity/skills/ccpm-verification/scripts/run-verify.sh` to execute tech-stack checks.

- The script loads the appropriate profile from `.gemini/context/verify/profiles/`
- Note the PASS or FAIL result.
- If PASS → proceed to Step 3.
- If FAIL → proceed to Step 2 (Ralph loop).

### Step 2 — Ralph Loop (only on failure)

Run `antigravity/skills/ccpm-verification/scripts/ralph-loop.sh` to manage the fix-and-retry cycle.

- Max 20 iterations by default.
- Protocol: fix the failing issue → re-run verification → check result.
- Repeat until PASS or max iterations reached.
- If max iterations reached: escalate to the user, do not close the issue.
- Once PASS → proceed to Step 3.

### Step 3 — Test Check

For FEATURE tasks: confirm test files exist.

- Run `antigravity/skills/ccpm-pre-implementation/scripts/check-tests.sh` (reuse from ccpm-pre-implementation).
- If no tests exist for a FEATURE task: BLOCKED — do not close.

### Step 4 — Semantic Review

Run `antigravity/skills/ccpm-verification/scripts/semantic-review.sh` to display the review checklist.

- Read through the checklist output.
- Address any items that are not satisfied.
- The checklist covers: correctness, error handling, tests, documentation, and design traceability.

### Step 5 — Write Verify Results

Update `.gemini/context/verify/state.json` with the final verification outcome.

- Set `current_iteration` to the final iteration count.
- Add an iteration record to the `iterations` array with: `{ "n": N, "result": "PASS"|"FAIL", "timestamp": "..." }`
- Use EXISTING schema fields only — do not add new fields.

## Anti-bypass

If you find yourself skipping verification, STOP. Unverified code has bugs. The verification pipeline exists because "it works on my machine" is not good enough — each step catches a different class of problem. All five steps must complete before marking a task done.

## Output Format

After completing all steps, present:

```
Verification complete:
- Verify run:      ✅ PASS / ❌ FAIL (iteration N)
- Ralph loop:      ✅ Resolved / ⚠️ Skipped / ❌ Max iterations
- Test check:      ✅ Tests found / ⚠️ Not FEATURE / ❌ Missing
- Semantic review: ✅ Checklist reviewed
- State written:   ✅ state.json updated

[If all pass]   → Ready to close issue.
[If any fails]  → BLOCKED. {What failed and what to do.}
```
