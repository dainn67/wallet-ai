# Categories Management Feature Documentation

## Technical Overview
The Categories Management system allows users to define and track financial classifications for their transactions. Each category is specifically typed as either 'income' or 'expense' and is used to group records for summary calculations.

## Technical Mapping

### UI Layer
- **CategoriesTab**: Displays the list of all categories with their total accumulated amounts. Uses `CategoryWidget` for each item. Tapping a category item (except "Uncategorized") directly opens the `CategoryFormDialog` for editing or deletion.
- **CategoryWidget**: A clean, minimal card component that follows the design pattern of `RecordWidget`. Displays the category icon, name, type, total amount, and a trailing chevron for interaction.
- **CategoryFormDialog**: Consolidated modal interface for category management. When editing, it provides both field modification and a dedicated Delete button that triggers a secondary confirmation step.

### Provider Layer
- **RecordProvider**: Manages the state and operations for categories.
  - `categories`: The list of all categories.
  - `getCategoryTotal(categoryId)`: Calculates the sum of all records belonging to a specific category.
  - `deleteCategory(categoryId)`: Removes a category and reassigns its records to "Uncategorized" (ID: 1).

### Repository Layer
- **RecordRepository**: Handles SQLite operations for the `Category` table.
  - `createCategory(category)`: Adds a new category to the database.
  - `updateCategory(category)`: Modifies an existing category's details.
  - `deleteCategory(categoryId)`: Removes the category and handles record cleanup (reassignment) within a transaction.

## Design Pattern (Category Card)

The `CategoryWidget` mimics the `RecordWidget` for visual consistency:
- **Rounded Corners**: 16px border radius.
- **Border & Shadow**: Subtle border (`#E2E8F0`) and soft shadow.
- **Icon Container**: Circular background with a color corresponding to its type (green for income, red for expense).
- **Typography**: Uses Poppins (the project standard) with specific weights for hierarchy.

## Data Relationships
- **Uncategorized (ID 1)**: The system-default category. It cannot be edited or deleted and serves as the destination for records whose category was deleted.
- **Type Restriction**: Categories are strictly typed. An income category only affects the income calculation of records, and vice versa.
