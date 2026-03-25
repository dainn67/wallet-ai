<!-- Source: Architecture decisions | Collected: 2026-03-25T06:35:15Z | Epic: reset-all -->

# Architecture Decisions

## Architecture Decisions

### AD-1: Reusable Confirmation Dialog
**Context:** Multiple features (Reset All, Delete Source, and potentially others in the future) require a standard way to confirm destructive actions.
**Decision:** Create a standalone `ConfirmationDialog` in `lib/components/popups/confirmation_dialog.dart`.
**Alternatives rejected:** Using inline `showDialog` calls in every screen (leads to duplication and inconsistent UI).
**Trade-off:** Slightly more upfront setup for a reusable component, but ensures visual consistency and easier maintenance.
**Reversibility:** Easy to modify the component's style globally.

### AD-2: Atomic Reset & Cascading Deletion
**Context:** Deleting data must be all-or-nothing to prevent inconsistent states (e.g., records deleted but balances not reset).
**Decision:** Implement `resetAllData` and an updated `deleteMoneySource` using SQLite `transaction`.
**Alternatives rejected:** Deleting records and updating sources in separate calls (risks state desync if one fails).
**Trade-off:** Requires careful handling of the database connection within transactions.
**Reversibility:** Hard to reverse data loss once committed, hence the mandatory confirmation UI.

