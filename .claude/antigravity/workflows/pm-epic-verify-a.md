---
name: pm-epic-verify-a
description: Epic Verify — Phase A: Semantic Review
# tier: heavy
---

# Epic Verify — Phase A: Semantic Review

Run Phase A Semantic Review for an epic. Collects all documentation via input assembly script, then analyzes completeness and produces a gap report.

## Usage
```
/pm:epic-verify-a <epic-name>
```

## Quick Check

Do not bother the user with preflight checks progress. Just do them silently.

1. Check epic exists:
   ```bash
   test -d .claude/epics/$EPIC_NAME || echo "❌ Epic '$EPIC_NAME' not found. Run: /pm:prd-parse $EPIC_NAME"
   ```

2. Check input assembly script exists:
   ```bash
   test -f .claude/scripts/epic-input-assembly.sh || echo "❌ Input assembly script not found at .claude/scripts/epic-input-assembly.sh"
   ```

3. Check config:
   ```bash
   if [ -f .claude/config/epic-verify.json ]; then
     python3 -c "import json; c=json.load(open('.claude/config/epic-verify.json')); print('disabled' if not c.get('phase_a',{}).get('enabled',True) else 'ok')"
   fi
   ```
   If disabled: "❌ Phase A is disabled in config. Update .claude/config/epic-verify.json"

4. Create reports directory:
   ```bash
   mkdir -p .claude/context/verify/epic-reports 2>/dev/null
   ```

## Role & Mindset

You are a Senior Technical Reviewer performing a Semantic Review of an epic. Your analysis is based ENTIRELY on provided documentation — you do not run code, you do not guess.

Your approach:
- Systematic: Cover every acceptance criteria, leave nothing unmapped
- Evidence-based: Every claim backed by specific document references
- Conservative: When in doubt, flag as a gap rather than assume "it's probably fine"
- Actionable: Every finding includes a concrete recommendation

If "Original Intent (from Memory)" section is present in the input, use it as an additional
verification dimension: check that implementation decisions align with original design decisions.
Flag any spec drift — cases where implementation diverged from original intent without
documented rationale. This is in addition to (not replacing) the standard completeness review.

## Instructions

### 0. Run Input Assembly

Collect all data sources:

```bash
EPIC_NAME="$EPIC_NAME"
OUTPUT_DIR="/tmp/epic-verify-${EPIC_NAME}"
rm -rf "$OUTPUT_DIR"
bash .claude/scripts/epic-input-assembly.sh "$EPIC_NAME" "$OUTPUT_DIR"
```

If the script fails, report the error and stop.

### 1. Read Assembled Data

Read ALL files from the output directory:

```bash
ls "$OUTPUT_DIR"/*.md
```

Read each file. These are your source documents for analysis:
- `01-epic-description.md` — Epic overview and goals
- `02-acceptance-criteria.md` — SOURCE OF TRUTH for coverage
- `03-issue-list.md` — All issues with status
- `04-issue-descriptions.md` — Full issue details
- `05-issue-status.md` — Issue states and labels
- `06-handoff-notes.md` — Developer handoff context
- `07-epic-context.md` — Accumulated epic context
- `08-architecture-decisions.md` — Architecture decisions
- `09-git-log.md` — Commit history
- `10-codebase-structure.md` — Current file structure
- `11-test-coverage.md` — Test coverage report
- `12-active-interfaces.md` — Active API/interfaces
- `13-known-issues.md` — Known issues (if available)
- `14-previous-reports.md` — Previous verify reports (if available)
- `15-diff-summary.md` — Git diff summary (if available)

Extract key metadata from the data:
- `{issue_count}`: Total number of issues
- `{closed_count}`: Number of closed issues
- `{open_count}`: Number of open issues

### 1b. Memory Agent: Original Intent (if available)

After reading the assembled data, check if Memory Agent can provide original intent:

1. Run:
   ```bash
   bash -c 'source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null && read_config_bool "memory_agent" "enabled" && read_config_bool "memory_agent" "query_on_verify" && echo "MEMORY_ENABLED"'
   ```
2. If output contains "MEMORY_ENABLED":
   - Run:
     ```bash
     source .claude/scripts/pm/lifecycle-helpers.sh && memory_query "original requirements design decisions constraints for epic: $EPIC_NAME" "markdown" "10"
     ```
   - If non-empty response: append to Phase A input context as:
     ```
     ## Original Intent (from Memory)
     {response}
     ```
   - Use this section during review to check:
     - Are implementation decisions consistent with original design intent?
     - Did any task deviate from requirements without documented rationale?
     - Are there consolidation warnings (decision_regression, architecture_drift)?
3. If not enabled or empty response: proceed with standard input (no section added)

### 2. Apply Phase A Prompt

Read the prompt template from `.claude/prompts/epic-phase-a.md`.

Replace placeholders with actual values:
- `{epic_name}` → the epic name from $EPIC_NAME
- `{issue_count}` → total issues found
- `{closed_count}` → closed issues count
- `{open_count}` → open issues count

Now perform ALL 6 analyses as specified in the prompt template, using the assembled data as your source material.

### 3. Write Report

Get current datetime:
```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

Generate timestamp for filename:
```bash
date -u +"%Y%m%d-%H%M%S"
```

Write report to: `.claude/context/verify/epic-reports/{epic-name}-{YYYYMMDD-HHMMSS}.md`

Report format:
```markdown
---
epic: {epic-name}
phase: A
generated: {ISO datetime}
assessment: EPIC_READY / EPIC_GAPS / EPIC_NOT_READY
quality_score: {X}/5
total_issues: {N}
closed_issues: {X}
open_issues: {Y}
---

# Epic Verification Report: {epic-name}
## Phase A: Semantic Review

**Generated:** {timestamp}
**Epic:** {epic-name}
**Total Issues:** {N} (Closed: {X}, Open: {Y})
**Overall Assessment:** 🟢 EPIC_READY / 🟡 EPIC_GAPS / 🔴 EPIC_NOT_READY
**Quality Score:** {X}/5

---

[6 analyses here — Coverage Matrix, Gap Report, Integration Risk Map, Quality Scorecard, Recommendations, Phase B Preparation]
```

### 4. Show Summary

After writing the report, display a concise summary:

```
✅ Phase A Semantic Review complete

Epic: {epic-name}
Report: .claude/context/verify/epic-reports/{filename}

Assessment: 🟢/🟡/🔴 {EPIC_READY/EPIC_GAPS/EPIC_NOT_READY}
Quality Score: {X}/5

Coverage: {covered}/{total} criteria covered
Gaps found: {N} ({critical} critical, {high} high, {medium} medium, {low} low)

Key findings:
  - {top 3 findings}
```

### 5. Developer Decision

Present 4 options and wait for the developer to choose:

```
What would you like to do?

1. Proceed to Phase B — Run integration tests
2. Fix gaps first — Address critical/high gaps before continuing
3. Accept gaps — Acknowledge gaps as technical debt, proceed to Phase B
4. Abort — Stop verification, continue development
```

Do NOT automatically proceed to Phase B. Wait for the developer's explicit choice.

## Error Handling

- Input assembly fails → "❌ Input assembly failed: {error}. Check .claude/scripts/epic-input-assembly.sh"
- No issues found → "❌ No issues found for epic '$EPIC_NAME'. Check GitHub labels."
- Config disabled → "❌ Phase A disabled in config."

## Important Notes

- This command does NOT run any code or tests — it only reads and analyzes documentation
- Report is saved for future reference and Phase B/C use
- Previous reports (if any) are available as context in the assembled data

## Next Steps (by developer choice)

- **Proceed to Phase B** → `/pm:epic-verify-b $EPIC_NAME`
- **Fix gaps first** → `/pm:epic-fix-gap $EPIC_NAME {id}` then re-run `/pm:epic-verify-a $EPIC_NAME`
- **Accept gaps** → `/pm:epic-accept-gaps $EPIC_NAME {ids}` then `/pm:epic-verify-b $EPIC_NAME`
- **Abort** → Continue development, re-run `/pm:epic-verify $EPIC_NAME` later
