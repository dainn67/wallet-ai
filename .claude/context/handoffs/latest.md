# Handoff: Task #108 - Add "Reset All Data" to HomeScreen drawer

## Summary
Added a "Data Management" section to the `HomeScreen` drawer with a "Reset All Data" button that triggers a confirmation dialog before resetting all application data.

## Key Changes
- **UI Layer**: Modified `lib/screens/home/home_screen.dart` to:
  - Add a "Data Management" section in the drawer.
  - Include a "Reset All Data" `ListTile` with destructive styling (red color).
  - Wired the button to show a `ConfirmationDialog` with a destructive confirmation button.
  - On confirmation, `RecordProvider.resetAllData()` is called and the drawer is closed.
- **Testing**: Added `test/screens/home/home_screen_test.dart` to verify:
  - Drawer presence and content.
  - Tapping "Reset All Data" opens the confirmation dialog.
  - Confirming the dialog calls the provider's reset method.

## Verification
- `flutter test test/screens/home/home_screen_test.dart` passed.
- `flutter analyze` passed.

## Technical Details
- Used `ConfirmationDialog` component for consistency and safety.
- Followed existing drawer styling for section headers and tiles.

## Next Steps
- Task #109: Add "Delete" button to `EditSourcePopup`.
