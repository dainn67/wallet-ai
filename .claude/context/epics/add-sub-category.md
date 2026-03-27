---
epic: add-sub-category
branch: epic/add-sub-category
started: 2026-03-27T08:43:33Z
status: in-progress
---
# Epic Context: add-sub-category

## Key Decisions
- **Hierarchical Category Model**: Use a self-referencing `parentId` in the `Category` table for simplicity and performance.
- **AI Classification**: Format the category list in the AI prompt to explicitly show the parent-sub relationship to improve accuracy.
- **UI Experience**: Use `ExpansionTile` in the Categories tab to manage nested lists and provide a clear grouping for users.

## Notes
- Initial setup complete. Branch `epic/add-sub-category` created and pushed.
- PRD and Epic files are synced to GitHub.
