---
name: pm-epic-edit
description: Epic Edit
# tier: medium
---

# Epic Edit

Edit epic details after creation.

## Usage
```
/pm:epic-edit <epic_name>
```

## Instructions

### 1. Read Current Epic

Read `.gemini/epics/$EPIC_NAME/epic.md`:
- Parse frontmatter
- Read content sections

### 2. Interactive Edit

Ask user what to edit:
- Name/Title
- Description/Overview
- Architecture decisions
- Technical approach
- Dependencies
- Success criteria

### 3. Update Epic File

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update epic.md:
- Preserve all frontmatter except `updated`
- Apply user's edits to content
- Update `updated` field with current datetime

### 4. Option to Update GitHub

If epic has GitHub URL in frontmatter:
Ask: "Update GitHub issue? (yes/no)"

If yes:
```bash
# Detect repo from epic's github: field
REPO=""
epic_github=$(grep '^github:' .gemini/epics/$EPIC_NAME/epic.md 2>/dev/null | head -1 | sed 's/^github: *//')
if [ -n "$epic_github" ]; then
  REPO=$(echo "$epic_github" | sed 's|https://github.com/||' | sed 's|/issues/.*||')
fi
if [ -z "$REPO" ]; then
  REPO=$(bash .gemini/scripts/pm/github-helpers.sh get-repo-for-issue 2>/dev/null || echo "")
fi

gh issue edit {issue_number} --repo "$REPO" --body-file .gemini/epics/$EPIC_NAME/epic.md
```

### 5. Output

```
✅ Updated epic: $EPIC_NAME
  Changes made to: {sections_edited}
  
{If GitHub updated}: GitHub issue updated ✅

View epic: /pm:epic-show $EPIC_NAME
```

## Important Notes

Preserve frontmatter history (created, github URL, etc.).
Don't change task files when editing epic.
Follow `.gemini/rules/frontmatter.md`.
