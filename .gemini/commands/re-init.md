---
allowed-tools: Bash, Read, Write, LS
---

# Re-init GEMINI.md

Refresh the project root `GEMINI.md` with the latest template from `.gemini/GEMINI.md`.

## Instructions

### Step 1: Check Files

```bash
test -f .gemini/GEMINI.md || { echo "❌ Template not found: .gemini/GEMINI.md"; exit 1; }
```

### Step 2: Update or Create

Read `.gemini/GEMINI.md` (the CCPM template).

- If `GEMINI.md` exists at project root:
  - Read both files
  - Replace the CCPM sections (Communication, Python Projects, Project Management, Rules) with the latest from template
  - **Preserve** any project-specific sections the user may have added (sections not present in the template)
  - Write the merged result back to `GEMINI.md`

- If `GEMINI.md` does NOT exist:
  - Copy `.gemini/GEMINI.md` to `GEMINI.md`

### Step 3: Output

```
✅ GEMINI.md updated from template

Sections refreshed:
  - Communication
  - Python Projects
  - Project Management (CCPM)
  - Rules

Next steps:
  - Review GEMINI.md for project-specific customizations
  - Run /pm:status to verify setup
```
