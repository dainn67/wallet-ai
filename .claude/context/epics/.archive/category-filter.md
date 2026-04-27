---
epic: category-filter
branch: epic/category-filter
started: 2026-04-25T14:51:21Z
status: in-progress
---
# Epic Context: category-filter

## Key Decisions
- **In-memory filter only** — no new SQLite queries; filter `RecordProvider._records` client-side
- **InkWell absorption** — setting `CategoryWidget.onTap` non-null makes its inner InkWell absorb taps; use this to cleanly separate "row tap → popup" from "chevron button → expand"
- **DraggableScrollableSheet** for popup — `initialChildSize: 0.6`, `maxChildSize: 0.95`, `backgroundColor: Colors.transparent`
- **StatelessWidget → StatefulWidget** on CategoriesTab required for `ExpansionTileController` map
- **Sub rows:** `onTap` now opens popup; edit moved to `onEdit` pencil icon (CategoryWidget already supports this)
- **Sort fix:** `RecordProvider` sort changes from `recordId DESC` to `occurredAt DESC`

## Notes
- GitHub epic issue: #187 (https://github.com/dainn67/wallet-ai/issues/187)
- Task issues: #188 (provider), #189 (bottom sheet), #190 (categories tab), #191 (verification)
- PRD sort assumption: code uses `recordId DESC`, not `lastUpdated` as PRD stated — fix direction unchanged (switch to `occurredAt DESC`)
- `getSubCategories(parentId)` already exists in RecordProvider (line 39)
- `_selectedDateRange` already exists in RecordProvider (line 28)
