---
name: Verify all widget sizes and run tests
status: closed
created: 2026-03-29T05:11:10Z
updated: 2026-03-29T05:22:28Z
complexity: simple
recommended_model: sonnet
phase: 3
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/149"
depends_on: [002]
parallel: false
conflicts_with: []
files:
  - lib/providers/record_provider.dart
  - android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt
prd_requirements:
  - FR-1
  - FR-2
  - FR-3
  - FR-4
  - NFR-1
  - NFR-2
---

# T3: Verify all widget sizes and run tests

## Context
After T1 (data fix) and T2 (layout redesign), we need to confirm that all changes work correctly together: Flutter tests pass, Kotlin builds, and all 5 widget size classes render properly on an emulator.

## Description
Run `flutter test` and `flutter analyze` to check for Dart-side regressions. Build the APK to verify Kotlin compilation. Deploy to an Android emulator and manually verify each widget size class (1×1, 1×2, 2×1, 2×2, 3×2+). Confirm data correctness: income/expense should reflect current-month totals, month label should match, currency formatting should be correct.

## Acceptance Criteria
- [ ] **FR-1:** 1×1 widget shows pencil icon + "Quick Record..." text, tap opens record entry
- [ ] **FR-2:** 1×2 shows balance + QuickRecordBar; 2×1 shows balance + QuickRecordBar horizontally
- [ ] **FR-3:** Income and expense values on widget match app's RecordsTab monthly-filtered totals
- [ ] **FR-4:** 2×2 and 3×2+ widgets display "March 2026" (or current month) in header
- [ ] **NFR-1:** Widget visually refreshes within 2 seconds of a record save
- [ ] **NFR-2:** All text in 1×1 layout ≥ 12sp; balance in large layout ≥ 24sp (visual check)
- [ ] No regressions: all existing Flutter tests pass (132/132)

## Implementation Steps

### Step 1: Run Flutter tests
- Execute `flutter test`
- All 132 tests must pass
- If any fail, investigate and fix before proceeding

### Step 2: Run Flutter analyze
- Execute `flutter analyze`
- Must report 0 errors and 0 warnings
- Fix any issues found

### Step 3: Build debug APK
- Execute `flutter build apk --debug`
- Must complete successfully (validates Kotlin compilation of AppWidget.kt changes)

### Step 4: Manual widget verification on emulator
- Deploy to Pixel 7 emulator (API 33+)
- Add the Wally AI widget at each size:
  1. **1×1:** Verify pencil icon + "Quick Record..." text visible. Tap → app opens to record entry.
  2. **1×2 (tall):** Verify balance amount + currency at top, QuickRecordBar at bottom.
  3. **2×1 (wide):** Verify balance on left, QuickRecordBar on right.
  4. **2×2:** Verify month label (e.g., "March 2026") + balance + income/expense row + QuickRecordBar.
  5. **3×2 or larger:** Verify WALLY AI tag + month label + full dashboard.

### Step 5: Verify data correctness
- Add a test income record (e.g., 500,000 VND) for the current month
- Add a test expense record (e.g., 200,000 VND) for the current month
- Check widget shows:
  - Income: "500.000" (VND format)
  - Spent: "200.000" (VND format)
  - Balance: sum of all money sources (not monthly)
  - Month: "March 2026"
- Open RecordsTab in app and verify values match

## Technical Details
- **Approach:** Verification-only task — no code changes expected unless bugs found
- **Files to check:** `lib/providers/record_provider.dart` (T1 changes), `android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt` (T2 changes)
- **Edge cases:**
  - Empty state (no records, no money sources) — widget should show "0" values
  - Very large numbers — text should not overlap or clip
  - Widget placed before app opened (no prefs written yet) — should show fallback "0" values

## Tests to Write
No new tests — this task validates existing tests and performs manual verification.

## Verification Checklist
- [ ] `flutter test` — 132/132 pass
- [ ] `flutter analyze` — 0 errors, 0 warnings
- [ ] `flutter build apk --debug` — success
- [ ] 1×1 widget renders correctly on emulator
- [ ] 1×2 widget renders correctly on emulator
- [ ] 2×1 widget renders correctly on emulator
- [ ] 2×2 widget shows month label + data
- [ ] 3×2+ widget shows full dashboard with month label
- [ ] Income/expense match RecordsTab values

## Dependencies
- **Blocked by:** T2
- **Blocks:** None
- **External:** Android emulator (Pixel 7, API 33+)
