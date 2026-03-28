# Categories Management Feature Documentation

## Technical Overview
The Categories Management system allows users to define and track financial classifications for their transactions. Each category is strictly typed as either 'income' or 'expense' and can be organized into a two-level hierarchy (Parent and Sub-categories). All category data and summary totals are persisted locally.

## Technical Mapping

### UI Layer
- **CategoriesTab**: Main interface for category management.
  - **Month Selector**: A horizontal control at the top that allows users to filter category totals by month/year.
  - **ExpansionTile Hierarchy**: Parent categories are shown as expandable cards. Expanding a card reveals its sub-categories.
  - **Add Sub Category Button**: A prominent full-width button (within the indented area) at the bottom of each parent's group to quickly create children.
- **CategoryWidget**: A consistent card component displaying:
  - **Icon**: Visual indicator of transaction type.
  - **Details**: Name, type label, and dynamic total amount.
  - **Context-Aware Padding**: Used for both standalone parent items and indented sub-category items.
- **CategoryFormDialog**: Modal for creating or editing categories.

### Provider Layer
- **RecordProvider**: Centralized logic for category data and reactive totals.
  - **Monthly Filter**: `selectedDateRange` defines the current viewing window (defaults to current month).
  - **In-Memory Calculation**: `_calculateCategoryTotals()` computes totals for all categories and their children by iterating through the cached `_records` list. This eliminates redundant database queries during month-to-month navigation.
  - **Parent Aggregation**: Parent category totals automatically include the sum of all their sub-categories' totals.
  - **Hierarchical Indexing**: `_subCategories` map stores pre-computed lists of children for efficient lookup by parent ID.

### Repository Layer
- **RecordRepository**: SQLite storage management.
  - **Category Table**: Includes `parent_id` (default: -1) for hierarchical associations.
  - **Date-Range Totals**: `getCategoryTotals()` supports server-side (disk) aggregation, though the provider currently performs this in-memory for immediate responsiveness.

## Hierarchy & Rules
- **Parent vs. Sub**: Parent categories have `parentId = -1`. Sub-categories point to their parent's ID.
- **Uncategorized (ID 1)**: The system-default category. It cannot be deleted and serves as a fallback.
- **Aggregated Totals**: The amount shown on a parent category's card is the aggregate sum of its own records and all its children's records within the filtered date range.
