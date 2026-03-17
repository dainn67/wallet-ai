---
model: sonnet
allowed-tools: Bash, Read
---

# Context Health

Diagnose the health of context files and report on potential issues.

## Usage
```
/pm:context-health
```

## Instructions

### 1. Handoff Notes

```bash
# Count handoff notes
total=$(find .claude/context/handoffs -maxdepth 1 -name "*.md" -not -name "TEMPLATE.md" -type f 2>/dev/null | wc -l | tr -d ' ')
archived=$(find .claude/context/handoffs/.archive -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

# Check latest freshness
if [ -f .claude/context/handoffs/latest.md ]; then
  age_min=$(( ($(date +%s) - $(stat -f %m .claude/context/handoffs/latest.md)) / 60 ))
fi
```

Report:
```
── Handoff Notes ──
  Active:   {total} notes
  Archived: {archived} notes
  Latest:   {age} minutes ago (or "missing")
  Rotation: {"needed" if total > 10, else "ok"}
```

### 2. Verify State

Read `.claude/context/verify/state.json` and report:
```
── Verification ──
  Active task: #{number} or "none"
  Mode:        {mode}
  Iterations:  {current}/{max}
  Last result: {result or "none"}
```

### 3. Context Size

```bash
du -sh .claude/context/ 2>/dev/null
du -sh .claude/context/handoffs/ 2>/dev/null
du -sh .claude/context/verify/ 2>/dev/null
du -sh .claude/context/epics/ 2>/dev/null
```

Report:
```
── Size ──
  Total:     {size}
  Handoffs:  {size}
  Verify:    {size}
  Epics:     {size}
```

### 4. Staleness Check

```bash
find .claude/context/ -name "*.md" -mtime +7 -type f 2>/dev/null
```

Report stale files (older than 7 days) that may need cleanup.

### 5. Summary

```
═══ Context Health Summary ═══
  Overall: {healthy/needs-attention/critical}

Recommendations:
  - {Any actionable suggestions}

Next: /pm:context-reset (if healthy) or /pm:handoff-write (if handoff missing)
```
