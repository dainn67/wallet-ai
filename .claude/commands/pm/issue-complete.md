---
model: sonnet
allowed-tools: Bash, Read, Write, LS
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
REPO=$(bash .claude/scripts/pm/github-helpers.sh get-repo-for-issue $ARGUMENTS 2>/dev/null || echo "")
```
If empty: "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."

Use `--repo "$REPO"` in ALL `gh` commands below (including the issue-close flow in step 4).

Check if `--no-learn` flag is present:
- If `$ARGUMENTS` contains `--no-learn` → set `SKIP_LEARN=true`, strip the flag from `$ARGUMENTS`
- Otherwise → `SKIP_LEARN=false`

### 2. Run Handoff Validation

Execute the post-task hook to validate the handoff note:
```bash
bash .claude/hooks/post-task.sh
```

If it exits non-zero:
- Show the output (it explains what's missing)
- Stop: "❌ Fix the handoff issues above, then try again."
- Suggest: "/pm:handoff-write to create a handoff note"

### 3. Run Verification

Check verify state in `.claude/context/verify/state.json`:

**If no active task** — initialize state first:
```bash
source .claude/scripts/pm/lifecycle-helpers.sh
init_verify_state $ARGUMENTS "$(basename $(ls -d .claude/epics/*/  | head -1))"
```

**If verify_mode is SKIP** — skip verification step.

**Otherwise** — run the verification profile:
```bash
source .claude/scripts/pm/lifecycle-helpers.sh
tech_stack=$(read_verify_state | jq -r '.active_task.tech_stack' 2>/dev/null || echo "generic")
profile=$(get_verify_profile "$tech_stack")
bash "$profile" .
```

If VERIFY_FAIL:
- Show output
- "❌ Verification failed. Fix the issues and run /pm:issue-complete $ARGUMENTS again."
- "Or: /pm:verify-skip <reason> to bypass verification."
- Stop here.

### 3.5. Knowledge Extract

Skip this step if `SKIP_LEARN=true`.

Read available context for knowledge extraction:
1. Check for debug journal: `.claude/context/sessions/issue-${ARGUMENTS}-debug.md`
2. Get changed files: `git diff HEAD~1 --name-only 2>/dev/null || echo ""`
3. Use issue body from step 1 JSON

Get close comment template:
```bash
template=$(bash .claude/scripts/knowledge-extract.sh extract $ARGUMENTS 2>/dev/null || echo "")
```

If template is non-empty, use it as scaffold: fill `Root cause`, `Fix`, and `Approaches tried` with analysis of the issue body, diff, and journal. Write final close comment to `/tmp/issue-close-comment-${ARGUMENTS}.md`.

Check for reusable patterns → if found, append to skillbook:
```bash
source .claude/scripts/pm/skillbook-extract.sh 2>/dev/null || true
append_skillbook_entry "helpful" "{keywords}" "standalone#${ARGUMENTS}" "{pattern body}"
```

If any error occurs → log warning, set `CLOSE_COMMENT=""`, continue. Do NOT block.

### 4. Close Issue

Run the issue-close flow:
- Update local task file status to `closed`
- If `/tmp/issue-close-comment-${ARGUMENTS}.md` exists, post it: `gh issue comment $ARGUMENTS --repo "$REPO" --body-file /tmp/issue-close-comment-${ARGUMENTS}.md`; then remove the temp file
- Close the issue: `gh issue close $ARGUMENTS --repo "$REPO"`
- Update epic checklist and progress

Follow the same steps as `/pm:issue-close $ARGUMENTS`.

### 4.5. Debug Journal Archive

Archive debug journal if it exists:
```bash
if [ -f ".claude/context/sessions/issue-${ARGUMENTS}-debug.md" ]; then
  summary=$(bash .claude/scripts/debug-journal-archive.sh archive $ARGUMENTS 2>/dev/null || echo "")
  JOURNAL_ARCHIVED=true
else
  JOURNAL_ARCHIVED=false
fi
```

Skip silently if no journal exists. Non-blocking — errors do not prevent completion.

### 5. Learning Extraction (ace-learning)

Check if skillbook is enabled and extract learnings from this task. Non-blocking — if disabled or extraction fails, skip silently.

```bash
source .claude/scripts/pm/skillbook-extract.sh
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

### 5.5. Memory Agent Auto-Ingest (if enabled)

After learning extraction, before context clear:

1. Check config:
   ```bash
   source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null
   read_config_bool "memory_agent" "enabled" && read_config_bool "memory_agent" "auto_ingest"
   ```
2. If both enabled, check health: `bash .claude/scripts/pm/memory-health.sh >/dev/null 2>&1`
3. If healthy, generate a structured task summary by analyzing:
   - The task file at `.claude/epics/*/$(printf '%03d' $ARGUMENTS).md` or similar (if available)
   - The handoff note at `.claude/context/handoffs/latest.md`
   - Extract: key decisions made, patterns used, blockers encountered, lessons learned
   - Format as structured plain text (NOT the handoff note itself — the file watcher handles that)

   Example format:
   ```
   Task #${ARGUMENTS} summary.
   Decisions: [key architectural/implementation decisions made]
   Patterns used: [reusable patterns applied]
   Blockers: [any blockers hit and how resolved]
   Lessons: [lessons learned for future tasks]
   ```

4. Ingest (fire-and-forget):
   ```bash
   source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null
   HOST=$(_json_get .claude/config/lifecycle.json '.memory_agent.host' 2>/dev/null || echo "localhost")
   PORT=$(_json_get .claude/config/lifecycle.json '.memory_agent.port' 2>/dev/null || echo "8888")
   [ "$HOST" = "null" ] || [ -z "$HOST" ] && HOST="localhost"
   [ "$PORT" = "null" ] || [ -z "$PORT" ] && PORT="8888"
   SUMMARY_JSON=$(echo "$SUMMARY" | jq -Rs .)
   curl -s --max-time 2 -X POST "http://${HOST}:${PORT}/ingest" \
     -H "Content-Type: application/json" \
     -d "{\"text\": ${SUMMARY_JSON}, \"source\": \"issue-complete-#${ARGUMENTS}\"}" \
     >/dev/null 2>&1 || true
   ```
5. If any step fails: continue silently — do NOT block issue completion.

### 6. Prepare Context Clear

Reset verify state:
```bash
echo '{"active_task": null}' > .claude/context/verify/state.json
```

### 7. Output

```
✅ Issue #$ARGUMENTS completed!
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
