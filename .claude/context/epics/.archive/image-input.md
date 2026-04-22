---
epic: image-input
branch: epic/image-input
started: 2026-04-21T16:55:41Z
status: in-progress
---
# Epic Context: image-input

## Key Decisions
(Record architecture decisions and rationale here)

- **AD-1 Compress on pick** — normalize/compress immediately on picker return; send path stays fast.
- **AD-2 Top-level `images` field** — JSON body gets a top-level `images: [base64...]`; server detects presence to branch extraction.
- **AD-3 No `permission_handler`** — rely on `image_picker` platform prompts (lazy, on first use).
- **AD-4 Transient `ChatMessage.imageBytes`** — in-memory only; not serialized to SQLite/JSON (mirrors `Record.suggestedCategory`).
- **AD-5 Small-image pass-through** — if longest edge ≤ 1600px AND size ≤ 500 KB, skip re-encoding.
- **AD-6 All-fail send** — if all attached images exceed 1.5 MB after compression, block send with inline error; no request made.

## Notes
(Accumulate context across sessions)

- PRD: `.claude/prds/image-input.md` (validation: WARNING, 22/30 passed, 7 non-blocking warnings).
- Epic: `.claude/epics/image-input/epic.md` — GitHub #169.
- Tasks: #170–#176 (7 tasks).
- Only ready task at start: #170 (Phase 1 deps + manifests). All others depend on #170 or later tasks.
- Server change (new `images` field) is out of scope for this epic — coordinate with server team separately.
