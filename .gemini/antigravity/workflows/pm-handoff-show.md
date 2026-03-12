---
name: pm-handoff-show
description: Handoff Show
# tier: medium
---

# Handoff Show

Display the latest handoff note.

## Usage
```
/pm:handoff-show
```

## Instructions

### 1. Check for Handoff Note

Read `.gemini/context/handoffs/latest.md`.

If it doesn't exist:
```
❌ No handoff note found at .gemini/context/handoffs/latest.md

Write one: /pm:handoff-write
Template:  .gemini/context/handoffs/TEMPLATE.md
```

### 2. Display Content

Display the full contents of `.gemini/context/handoffs/latest.md`.

### 3. Show Metadata

After displaying, show:
```
---
Last modified: {file modification time}
```

If the file is older than 10 minutes, add:
```
⚠️ This handoff note may be stale (older than 10 minutes).
   Update it: /pm:handoff-write
```
