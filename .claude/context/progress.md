---
created: 2026-05-24T05:30:37Z
last_updated: 2026-05-24T05:30:37Z
version: 1.0
author: Claude Code PM System
---

# Progress

## Current Branch
`main` — clean tracking branch. Active development merges directly via PR.

## Recent Work (last 10 commits)
- `4786791` feat: add transfer feature from chat
- `a7a9b19` refactor: extract TransferInfoPopup from EditRecordPopup
- `d287cab` feat: transfer between money sources
- `9bd99d9` minor changes
- `80607b3` Merge PR #198 from epic/onboarding
- `dfad293` feat(locale): auto-detect language and currency on first launch
- `b9dfbcf` feat: source amount masking, drawer share, onboarding redesign
- `09318c2` [Epic-Complete] onboarding — verified and closed
- `eaf514d` Issue #197: Mark onboarding epic complete after verification
- `ddf3328` Issue #196: Fix lint warnings

## Uncommitted Changes
- `android/app/build.gradle.kts` — added `resolutionStrategy` forcing `androidx.glance:*` to `1.1.1` to override `home_widget`'s dynamic `1.+` resolving to alpha that required compileSdk 37 + AGP 9.1.
- `lib/screens/home/tabs/chat_tab.dart` — auto-scroll fix: removed "near bottom" guard so chat scrolls to bottom on every streaming event and on user send. Switched `_scrollToBottom` to `jumpTo` to avoid 300ms animateTo conflicts during rapid chunks.

## Most Recent Feature
**Transfer from chat** — the AI parser now emits `type: 'transfer'` records with `target_source_id`. Client ignores any AI-supplied category and resolves the seeded Transfer category via `RecordProvider.transferCategory`. Invalid transfers (missing/self-referential target) are skipped without aborting the batch. Schema migration v8 → v9 adds nullable `target_source_id` and relaxes the `type` CHECK.

## Immediate Next Steps
- Decide whether to commit current uncommitted fixes (AAR metadata + chat auto-scroll) — they're independent and small.
- iOS App Store submission still pending — share-app copy currently omits the App Store URL until then.
- Watch for any `home_widget` upgrade that drops the dynamic version (would let us remove the resolutionStrategy).

## Outstanding Considerations
- `EditRecordPopup` for transfers is delete-only (v1). Editing transfer details would require splitting the popup or building a richer form.
- `compileSdk` is pinned by Flutter via `flutter.compileSdkVersion`; bumping to 37 requires AGP 9.x — out of scope until Flutter ships compatible defaults.
