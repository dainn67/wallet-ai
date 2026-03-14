# Handoff: Task #8 - Implement dynamic environment switching in AppConfig

## Status
- [x] Task #8 completed.
- [x] `AppConfig` updated to use `const String.fromEnvironment('ENVIRONMENT')`.
- [x] Added `AppEnvironment` enum for better type safety.
- [x] Implemented default to `dev` environment.
- [x] Created `test/config/app_config_test.dart` and verified switching logic.

## Changes
- `lib/config/app_config.dart`:
    - Changed `environment` to `final` and initialized it using `_getEnvironment()` helper.
    - `_getEnvironment()` uses `const String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev')`.
- `test/config/app_config_test.dart`:
    - New test file to verify `AppConfig` properties and environment switching.

## Verification
- Ran `fvm flutter test test/config/app_config_test.dart` (Passed).
- Ran `fvm flutter test --dart-define=ENVIRONMENT=prod test/config/app_config_test.dart` (Passed).

## Next Steps
- Continue with the next tasks in the `api-service-and-config` epic, potentially involving API client setup using this configuration.
