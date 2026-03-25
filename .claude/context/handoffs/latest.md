# Handoff: Task #117 → Task #118

## Completed
- Implemented the destructive currency change flow in `HomeScreen` drawer.
- Added localized confirmation strings for currency change in `L10nConfig`.
- Integrated `RecordProvider.resetAllData()` with the currency update logic.
- Ensured currency only updates after user confirmation and database wipe.

## Decisions Made
- Used `RecordProvider.resetAllData()` from the previous epic to ensure atomicity.
- Added specific translation keys (`currency_change_confirm_title/content`) to distinguish from general data reset warnings.

## Interfaces Exposed/Modified
- `LocaleProvider.setCurrency(AppCurrency curr)`: Persists and notifies.
- `HomeScreen`: UI logic updated to handle asynchronous currency selection and confirmation.

## State of Tests
- Manual verification of dialog flow and data wipe.
- Next task (#118) will add automated integration tests for this flow.

## Warnings for Next Task
- Task #118 should verify that `resetAllData` is called **before** `setCurrency` to prevent any data being associated with the new currency by mistake during the transition.

## Files Changed
- `lib/configs/l10n_config.dart` (modified)
- `lib/screens/home/home_screen.dart` (modified)
- `.claude/epics/update-language-and-currency/117.md` (closed)
