---
model: sonnet
allowed-tools: Bash, Read, Write, LS
---

# PRD Edit

Edit an existing Product Requirements Document with context awareness and impact analysis.

## Usage
```
/pm:prd-edit <feature_name>
```

## Preflight (silent)

1. **Validate `$ARGUMENTS`:** kebab-case, non-empty. If invalid → error with usage hint.
2. **Locate PRD:** `.claude/prds/$ARGUMENTS.md` must exist. If not → `❌ PRD not found. Run: /pm:prd-new $ARGUMENTS`

## Role & Mindset

Same PM as prd-new but in revision mode. Focus on: consistency after edits, downstream impact, scope control.

## Instructions

### 1. Load Context

Read (skip silently if missing):
- `.claude/prds/$ARGUMENTS.md` — the PRD
- `.claude/prds/.validation-$ARGUMENTS.md` — validation report (if exists)
- `.claude/context/tech-context.md` — technical constraints
- `.claude/epics/$ARGUMENTS/epic.md` — associated epic (if exists)
- `.claude/rules-reference/prd-quality.md` — quality standards reference

**Snapshot before edit:** Record current requirement IDs (FR-1, NTH-1, NFR-1...) for impact analysis.

### 2. Choose Edit Mode

**Validation-driven** (if validation report exists with issues):
- Show: "Found validation report with N issues. Fix these first?"
- If yes → present issues one by one, apply fixes
- If no → fall through to Interactive

**Interactive** (default):
- Show section overview with status indicators:
  ```
  PRD: $ARGUMENTS (scale: medium, priority: P1)

  Sections:
  1. Executive Summary     ✅ (3 sentences)
  2. Problem Statement     ✅
  3. Target Users          ✅ (3 personas)
  4. User Stories           ✅ (5 stories)
  5. Requirements          ✅ (4 FR, 2 NTH, 3 NFR)
  6. Success Criteria      ⚠️ (1 missing threshold)
  7. Risks & Mitigations   ✅ (4 risks)
  8. Constraints           ✅
  9. Out of Scope          ✅
  10. Dependencies          ✅

  Which sections to edit? (numbers, comma-separated)
  ```

**Surgical** (if user specifies intent in args, e.g. "add a new requirement"):
- Apply targeted change directly
- Show diff of what changed

### 3. Apply Edits

For each edited section:
- Apply user's changes
- Validate edited section against `.claude/rules-reference/prd-quality.md` quality standards
- If new requirements added → assign next sequential ID (FR-N+1)
- If requirements removed → do NOT reuse IDs

### 4. Post-Edit Quality

After all edits applied:
- Re-check edited sections only against quality standards
- If issues found → show and offer to fix inline

### 5. Impact Analysis

Compare requirement IDs before/after edit:
- **Added:** List new IDs
- **Removed:** List removed IDs → warn: "Removed requirements may affect downstream epic/tasks"
- **Modified:** List IDs with changed scenarios

If epic exists AND requirements changed:
```
⚠️ Downstream impact detected:
  Added: FR-5, NFR-4
  Removed: NTH-2
  Modified: FR-2 (scenario changed)

  Epic .claude/epics/$ARGUMENTS/epic.md may need updating.
```

### 6. Update PRD

- Update `updated` field with current datetime (preserve `created`)
- Update `_Metadata` block: recalculate `requirement_ids`, set `validation_status: pending`
- Save PRD

### 7. Output

```
✅ Updated PRD: $ARGUMENTS
  Sections edited: [list]
  Requirements: +N added, -M removed, ~K modified

{If epic exists + changes}: ⚠️ Epic may need review: /pm:epic-edit $ARGUMENTS
{If validation report exists}: Consider re-validating: /pm:prd-validate $ARGUMENTS

📋 Next actions:
  → Validate:     /pm:prd-validate $ARGUMENTS
  → Create epic:  /pm:prd-parse $ARGUMENTS
  → View PRD:     /pm:prd-status $ARGUMENTS
```

## Important Notes

- Preserve original `created` date. Only update `updated`.
- Never reuse deleted requirement IDs.
- Follow `rules/frontmatter.md` for datetime handling.
