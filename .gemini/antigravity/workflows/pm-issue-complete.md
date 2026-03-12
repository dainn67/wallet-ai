---
name: pm-issue-complete
description: Issue Complete
# tier: medium
---

# Issue Complete

Run the full task completion flow: validate handoff, trigger verification, sync issue, and prepare for context clear.

## Usage
```
/pm:issue-complete <issue_number>
```

## Instructions

### 1. Validate Arguments and Detect Repo

If no issue number provided: "❌ Usage: /pm:issue-complete <issue_number>"

```bash
REPO=$(bash .gemini/scripts/pm/github-helpers.sh get-repo-for-issue $ISSUE_NUMBER 2>/dev/null || echo "")
```
If empty: "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."

Use `--repo "$REPO"` in ALL `gh` commands below (including the issue-close flow in step 4).

Check if `--no-learn` flag is present:
- If `$ISSUE_NUMBER` contains `--no-learn` → set `SKIP_LEARN=true`, strip the flag from `$ISSUE_NUMBER`
- Otherwise → `SKIP_LEARN=false`

### 2. Run Handoff Validation

Execute the post-task hook to validate the handoff note:
```bash
bash .gemini/hooks/post-task.sh
```

If it exits non-zero:
- Show the output (it explains what's missing)
- Stop: "❌ Fix the handoff issues above, then try again."
- Suggest: "/pm:handoff-write to create a handoff note"

### 3. Run Verification

Check verify state in `.gemini/context/verify/state.json`:

**If no active task** — initialize state first:
```bash
source .gemini/scripts/pm/lifecycle-helpers.sh
init_verify_state $ISSUE_NUMBER "$(basename $(ls -d .gemini/epics/*/  | head -1))"
```

**If verify_mode is SKIP** — skip verification step.

**Otherwise** — run the verification profile:
```bash
source .gemini/scripts/pm/lifecycle-helpers.sh
tech_stack=$(read_verify_state | jq -r '.active_task.tech_stack' 2>/dev/null || echo "generic")
profile=$(get_verify_profile "$tech_stack")
bash "$profile" .
```

If VERIFY_FAIL:
- Show output
- "❌ Verification failed. Fix the issues and run /pm:issue-complete $ISSUE_NUMBER again."
- "Or: /pm:verify-skip <reason> to bypass verification."
- Stop here.

### 3.5. Knowledge Extract

Skip this step if `SKIP_LEARN=true`.

Read available context for knowledge extraction:
1. Check for debug journal: `.gemini/context/sessions/issue-${ARGUMENTS}-debug.md`
2. Get changed files: `git diff HEAD~1 --name-only 2>/dev/null || echo ""`
3. Use issue body from step 1 JSON

Get close comment template:
```bash
template=$(bash .gemini/scripts/knowledge-extract.sh extract $ISSUE_NUMBER 2>/dev/null || echo "")
```

If template is non-empty, use it as scaffold: fill `Root cause`, `Fix`, and `Approaches tried` with analysis of the issue body, diff, and journal. Write final close comment to `/tmp/issue-close-comment-${ARGUMENTS}.md`.

Check for reusable patterns → if found, append to skillbook:
```bash
source .gemini/scripts/pm/skillbook-extract.sh 2>/dev/null || true
append_skillbook_entry "helpful" "{keywords}" "standalone#${ARGUMENTS}" "{pattern body}"
```

If any error occurs → log warning, set `CLOSE_COMMENT=""`, continue. Do NOT block.

### 4. Close Issue

Run the issue-close flow:
- Update local task file status to `closed`
- If `/tmp/issue-close-comment-${ARGUMENTS}.md` exists, post it: `gh issue comment $ISSUE_NUMBER --repo "$REPO" --body-file /tmp/issue-close-comment-${ARGUMENTS}.md`; then remove the temp file
- Close the issue: `gh issue close $ISSUE_NUMBER --repo "$REPO"`
- Update epic checklist and progress

Follow the same steps as `/pm:issue-close $ISSUE_NUMBER`.

### 4.5. Debug Journal Archive

Archive debug journal if it exists:
```bash
if [ -f ".gemini/context/sessions/issue-${ARGUMENTS}-debug.md" ]; then
  summary=$(bash .gemini/scripts/debug-journal-archive.sh archive $ISSUE_NUMBER 2>/dev/null || echo "")
  JOURNAL_ARCHIVED=true
else
  JOURNAL_ARCHIVED=false
fi
```

Skip silently if no journal exists. Non-blocking — errors do not prevent completion.

### 5. Learning Extraction (ace-learning)

Check if skillbook is enabled and extract learnings from this task. Non-blocking — if disabled or extraction fails, skip silently.

```bash
source .gemini/scripts/pm/skillbook-extract.sh
extract_learnings "{epic_name}" "{issue_number}"
```

If `ace_feature_enabled "skillbook"` returns false, the function exits immediately. Otherwise it outputs an extraction context block. Analyze the output and extract 0-3 learnings:
- Reusable pattern that worked well
- Pitfall to avoid
- Effective approach for similar tasks

For each learning worth capturing, call:
```bash
append_skillbook_entry "{pattern_type}" "{context_keywords}" "epic/{epic_name}#{issue_number}" "{body}"
```

If extraction returns "nothing noteworthy" or the output is empty/malformed → skip. Do NOT block issue completion.

### 6. Prepare Context Clear

Reset verify state:
```bash
echo '{"active_task": null}' > .gemini/context/verify/state.json
```

### 7. Output

```
✅ Issue #$ISSUE_NUMBER completed!
  Handoff:      ✅ Validated
  Verification: ✅ Passed (or Skipped)
  Knowledge:    ✅ Extracted (or ⏭️ Skipped with --no-learn)
  Journal:      ✅ Archived (or ⏭️ No journal)
  GitHub:       ✅ Issue closed
  Context:      ✅ Ready to clear

Run /clear to reset conversation context.
Your work is preserved in handoff notes and git commits.

Next:
  - More issues to do: /pm:next [light/haiku]
  - All issues closed: /pm:epic-verify {epic_name} [heavy/opus]
  - Standalone issue? You're done! Run /clear
```
