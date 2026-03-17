---
allowed-tools: Bash, Read, Write, LS
---

# Re-init CLAUDE.md

Refresh the project root `CLAUDE.md` with the latest template from `.claude/CLAUDE.md`.

## Instructions

### Step 1: Check Files

```bash
test -f .claude/CLAUDE.md || { echo "❌ Template not found: .claude/CLAUDE.md"; exit 1; }
```

### Step 2: Update or Create

Read `.claude/CLAUDE.md` (the CCPM template).

- If `CLAUDE.md` exists at project root:
  - Read both files
  - Replace the CCPM sections (Communication, Python Projects, Project Management, Rules) with the latest from template
  - **Preserve** any project-specific sections the user may have added (sections not present in the template)
  - Write the merged result back to `CLAUDE.md`

- If `CLAUDE.md` does NOT exist:
  - Copy `.claude/CLAUDE.md` to `CLAUDE.md`

### Step 3: Output

```
✅ CLAUDE.md updated from template

Sections refreshed:
  - Communication
  - Python Projects
  - Project Management (CCPM)
  - Rules

Next steps:
  - Review CLAUDE.md for project-specific customizations
  - Run /pm:status to verify setup
```
