---
epic: reset-all
branch: epic/reset-all
started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
status: in-progress
---
# Epic Context: reset-all

## Key Decisions
- Implement a reusable ConfirmationDialog to handle destructive actions (AD-1).
- Use database transactions in RecordRepository for atomic reset and cascading deletions (AD-2).

## Notes
- Initial setup for reset-all feature.
