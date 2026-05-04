---
epic: onboarding
branch: epic/onboarding
started: 2026-04-28T04:48:05Z
status: in-progress
---
# Epic Context: onboarding

## Key Decisions
- Trigger via `HomeScreen.initState()` + `addPostFrameCallback` (not in `main.dart`)
- Block dismissal with `showDialog(barrierDismissible: false)` + `PopScope(canPop: false)`
- Slide config as a private `const` list inside the widget file (no separate config class)
- SharedPreferences key: `onboarding_complete`
- No new packages — `shared_preferences` already in deps

## Notes
(Accumulate context across sessions)
