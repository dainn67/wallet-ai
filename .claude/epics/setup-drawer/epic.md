---
name: setup-drawer
status: backlog
created: 2026-03-22T00:00:00Z
updated: 2026-03-22T00:00:00Z
progress: 0%
priority: P1
prd: .claude/prds/setup-drawer.md
task_count: 5
github: https://github.com/dainn67/wallet-ai/issues/98
---

# Epic: setup-drawer

## Overview
This epic transforms the app drawer into a utility hub. We'll remove redundant navigation items, implement a versioning system that stays in sync with `pubspec.yaml` via a Python script, and add a currency toggle (VND/USD) persisted in `SharedPreferences`.

## Architecture Decisions
### AD-1: Version Synchronization Strategy
**Context:** App versioning exists in `pubspec.yaml`, but needs to be accessible in Dart code for display.
**Decision:** Create a Python script to update both `pubspec.yaml` and a hardcoded string in `AppConfig`.
**Rationale:** Avoids the overhead of `package_info_plus` if only simple display is needed, and provides a single source of truth for build automation.
**Reversibility:** Hard (moving to `package_info_plus` later would require removing the script logic).

### AD-2: Preference Persistence Pattern
**Context:** Currency preference needs to be saved and recalled.
**Decision:** Use the existing `StorageService` (wrapper for `SharedPreferences`).
**Rationale:** Aligns with existing project patterns for simple key-value storage.

## Technical Approach
### UI Layer (Drawer)
- **Modify `lib/screens/home/home_screen.dart`**:
    - Remove the `ListTile` items for Chat, Records, and Test.
    - Add a "Settings" section header.
    - Implement a `SwitchListTile` or custom toggle for Currency (VND vs USD).
    - Add a `Padding` + `Text` widget at the very bottom of the drawer's `Column` to display the version string.

### Configuration Layer
- **Modify `lib/configs/app_config.dart`**:
    - Add `String appVersion = '1.0.0';`
    - Add `String buildNumber = '2';`

### Automation Layer
- **Create `scripts/update_version.py`**:
    - Input: A string in format `x.y.z+b`.
    - Regex-based replacement in `pubspec.yaml`.
    - Regex-based replacement in `lib/configs/app_config.dart`.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Drawer Cleanup | §UI Layer | 99 | Visual check |
| FR-2: Version Config | §Config Layer | 100 | Display check |
| FR-3: Sync Script | §Automation Layer | 101 | Run script, check files |
| FR-4: Currency Toggle | §UI Layer | 102 | Toggle, restart app, check persistence |
| NFR-1: UI Consistency | §UI Layer | 99, 102 | Styled as per PRD |

## Implementation Strategy
### Phase 1: Cleanup & Versioning
Remove old items and set up the static version display.
- Exit criterion: Drawer is clean and shows a hardcoded version.
### Phase 2: Automation
Implement the Python sync script.
- Exit criterion: Script updates both files correctly.
### Phase 3: Functionality
Implement the currency toggle and persistence.
- Exit criterion: Currency can be changed and is saved.

## Tasks Created
| #   | Task | Phase | Parallel | Est. | Depends On | Status |
| --- | ---- | ----- | -------- | ---- | ---------- | ------ |
| 99 | Drawer UI Cleanup | 1 | no | 0.5d | — | open |
| 100 | AppConfig Version Support | 1 | no | 0.2d | — | open |
| 101 | Python Sync Script | 2 | yes | 0.5d | 100 | open |
| 102 | Currency Toggle | 3 | no | 0.5d | — | open |
| 103 | Verification & Polish | 3 | no | 0.3d | all | open |

### Summary
- **Total tasks:** 5
- **Parallel tasks:** 1
- **Sequential tasks:** 4
- **Estimated total effort:** 2d
- **Critical path:** 99 → 100 → 101 → 102 → 103 (~2d)

### Dependency Graph
```
  99 ──┐
       ├──→ 103
  100 ─┼─→ 101 ──→ 103
  102 ─┘
```

### PRD Coverage
| PRD Requirement | Covered By | Status |
| --------------- | ---------- | ------ |
| FR-1: Drawer Cleanup | 99 | ✅ Covered |
| FR-2: Version Config | 100 | ✅ Covered |
| FR-3: Sync Script | 101 | ✅ Covered |
| FR-4: Currency Toggle | 102 | ✅ Covered |
| NFR-1: Consistency | 99 | ✅ Covered |

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Regex failures in script | Medium | Low | Corrupt files | Use strict patterns and provide a "dry run" or validation step. |

## Success Criteria (Technical)
- Running `python3 scripts/update_version.py 1.2.3+4` results in `version: 1.2.3+4` in `pubspec.yaml` and matching values in `AppConfig`.
- The string `v1.2.3(4)` is visible at the bottom of the drawer.
- Changing currency to USD persists after an app restart.

## Estimated Effort
- **Total Estimate:** 2 days
- **Critical Path:** 2 days

## Deferred / Follow-up
- Editing existing sources (not requested).
- Custom icons for sources (not requested).
