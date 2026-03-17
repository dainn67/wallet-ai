---
model: sonnet
allowed-tools: Bash, Read, Glob
---

# Epic Verify — History

Display the history of all verification runs for an epic.

## Usage
```
/pm:epic-verify-history <epic-name>
```

## Instructions

### 1. Find Reports

```bash
EPIC_NAME="$ARGUMENTS"
REPORTS=$(ls -t .claude/context/verify/epic-reports/${EPIC_NAME}-*.md 2>/dev/null)
```

If no reports found:
```
No verification history for epic '$ARGUMENTS'.
  Run: /pm:epic-verify $ARGUMENTS to start verification.
```
Stop here.

### 2. Parse Reports

For each report file, read the frontmatter and extract:
- `generated` (timestamp)
- `phase` (A / final)
- `assessment` or `final_decision`
- `quality_score`
- `total_iterations` (for final reports)

### 3. Display History

```
═══ Epic Verify History: {epic_name} ═══

Reports found: {count}

| #  | Date                | Phase | Assessment       | Quality | Iterations |
| -- | ------------------- | ----- | ---------------- | ------- | ---------- |
| 1  | 2026-02-20 10:00:00 | A     | EPIC_READY       | 4/5     | —          |
| 2  | 2026-02-20 12:00:00 | Final | EPIC_COMPLETE    | 4/5     | 3          |
```

Sort by date (newest first).

Use emojis for assessment:
- EPIC_READY / EPIC_COMPLETE → `✅`
- EPIC_GAPS / EPIC_PARTIAL → `⚠️`
- EPIC_NOT_READY / EPIC_BLOCKED → `❌`

### 4. Show Current State

Check if there's an active verification:
```bash
cat .claude/context/verify/epic-state.json 2>/dev/null
```

If `active_epic` matches `$ARGUMENTS`:
```
Active verification: Phase {phase}, Iteration {current}/{max}
  Status: /pm:epic-verify-status $ARGUMENTS
```

If no active verification:
```
No active verification.
  Latest report: /pm:epic-verify-report $ARGUMENTS
  Start new:     /pm:epic-verify $ARGUMENTS
```

## Error Handling

- No arguments → "❌ Usage: /pm:epic-verify-history <epic-name>"
- No reports → Clear message with next step
- Malformed report frontmatter → Skip that report, show available data
