---
epic: refactor-code
branch: epic/refactor-code
started: 2026-03-28T18:09:46Z
status: in-progress
---
# Epic Context: refactor-code

## Key Decisions
- AD-1: Provider-only repo access — ChatProvider must go through RecordProvider
- AD-2: Extract CRUD boilerplate into _performOperation() helper in RecordProvider
- AD-3: Move ChatBubble and AddSubCategoryDialog to lib/components/
- AD-4: Import ordering: dart → flutter → third-party → wallet_ai → relative

## Notes
- RecordRepository at 513 lines exceeds 400-line threshold — deferred to separate initiative
- ChatProvider creates records in a loop from parsed JSON — new createRecord() must return int ID
- RecordProvider has 9 CRUD methods with subtle behavioral differences to preserve
