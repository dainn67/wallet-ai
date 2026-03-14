# Handoff: Task #9 - Refine ApiService and ApiException

## Status
- [x] Task #9 completed.
- [x] `ApiService` refined to use `AppConfig` for initialization.
- [x] `ApiException` refined with granular error mapping for HTTP status codes (401, 404, 500).
- [x] Core HTTP methods (GET, POST, PUT, DELETE) implemented with error handling.
- [x] Added unit tests for `ApiException` and `ApiService`.
- [x] Added `mocktail` to `dev_dependencies` for testing.

## Changes
- `lib/services/api_exception.dart`:
    - Updated `fromDioException` to handle specific status codes in `badResponse`.
- `lib/services/api_service.dart`:
    - Constructor now sets `BaseOptions` and adds `PrettyDioLogger`.
    - Methods now wrap `DioException` and throw `ApiException`.
- `test/services/api_exception_test.dart`:
    - New unit tests for error mapping.
- `test/services/api_service_test.dart`:
    - New unit tests for initialization and method calls using `mocktail`.
- `pubspec.yaml`:
    - Added `mocktail: ^1.0.4` to `dev_dependencies`.

## Verification
- Ran `fvm flutter test test/services/api_exception_test.dart test/services/api_service_test.dart` (All 11 tests passed).

## Next Steps
- Use `ApiService` for implementing specific feature repositories or services.
- Task #10: Integrate ApiService with AuthProvider (if applicable).
