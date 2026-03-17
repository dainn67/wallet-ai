---
name: ccpm-epic-verify
description: Use when verify epic, check epic quality, epic ready to merge, run epic verification, is epic done. NOT for: task-level verify (done, complete, close issue), gap fixing, planning gaps.
---

# CCPM Epic Verify

Run the 2-phase epic verification pipeline: Phase A (Semantic Review) then Phase B (Integration Tests).

## Steps

**SEQUENTIAL — do not skip any step.**

### Step 1 — Phase A: Semantic Review

Run `antigravity/skills/ccpm-epic-verify/scripts/phase-a.sh` to gather epic context and review criteria.

The script will:
- Assemble epic context via `.claude/scripts/epic-input-assembly.sh` if available
- Load review criteria from `.claude/prompts/epic-phase-a.md`
- Read current epic state from `.claude/context/verify/epic-state.json`
- Output the structured prompt and template for semantic review

Using the context output from the script, perform semantic review and produce:

**Coverage Matrix** — for each epic requirement, mark ✅ covered / ❌ missing / ⚠️ partial

**Gap Report** — for each gap found:
- Severity: CRITICAL / HIGH / MEDIUM / LOW
- Description of what is missing
- Recommendation

**Quality Scorecard** — score 1–5 on:
- Requirements coverage
- Test coverage
- Documentation quality
- Implementation completeness
- Integration readiness

**Assessment** — one of:
- `EPIC_READY` — all critical requirements met, ready for Phase B
- `EPIC_GAPS` — gaps exist but non-blocking, can proceed to Phase B
- `EPIC_NOT_READY` — critical gaps block Phase B

### Step 2 — Developer Review Pause

Present Phase A results and wait for developer decision:

1. **Proceed to Phase B** — continue to integration tests
2. **Fix gaps first** — stop here, developer addresses gaps, then re-run
3. **Accept gaps as tech debt** — acknowledge gaps, proceed to Phase B
4. **Abort** — stop verification, continue development

**Wait for explicit developer choice.** Do not auto-proceed.

- Option 1 or 3 → continue to Step 3
- Option 2 → STOP. "Fix gaps and re-run epic verify."
- Option 4 → STOP. "Verification aborted."

### Step 3 — Phase B: Integration Tests

**Only run Phase B if Phase A assessment is EPIC_READY or EPIC_GAPS.**

If Phase A returned EPIC_NOT_READY, STOP and do not run Phase B.

Run `antigravity/skills/ccpm-epic-verify/scripts/phase-b.sh` to execute integration verification.

The script will:
- Run `.claude/context/verify/epic-verify.sh` if available, or fall back to generic profiles
- Output current iteration status and test results
- Instruct you on fail→fix→retry actions (Ralph loop)

**Ralph loop:**
- On FAIL: read the failing tests, fix the issue, then re-run phase-b.sh
- Continue until PASS or max iterations reached
- Max iterations is read from `.claude/config/epic-verify.json` (default: 30)

**4-tier test sequence:** smoke → integration → regression → performance

### Step 4 — Report Results

After Phase B completes, report:

```
═══════════════════════════════════════════
  Epic Verification Complete
═══════════════════════════════════════════

Phase A: {EPIC_READY / EPIC_GAPS / EPIC_NOT_READY}
Phase B: {PASS / FAIL / PARTIAL}

Quality Score: {X}/5
Iterations:    {N}

Next: /pm:epic-merge {epic_name}   (if EPIC_COMPLETE)
      /pm:epic-gaps {epic_name}    (if gaps remain)
```

## Anti-bypass

If you find yourself skipping Phase A or Phase B, STOP. Both phases exist for a reason:
- Phase A catches documentation and coverage gaps before running tests
- Phase B validates integration and catches runtime failures

Both gates must pass before an epic is considered verified.
