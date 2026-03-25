<!-- Source: git diff | Collected: 2026-03-25T06:35:15Z | Epic: reset-all -->

# Diff Summary

Changes from `689611b1` to `HEAD`:

```
 .claude/context/epics/reset-all.md                 |  14 ++
 .claude/context/handoffs/latest.md                 |  29 ++---
 .claude/epics/reset-all/105.md                     |  10 +-
 .claude/epics/reset-all/106.md                     |   8 +-
 .claude/epics/reset-all/107.md                     |   6 +-
 .claude/epics/reset-all/108.md                     |  32 ++---
 .claude/epics/reset-all/109.md                     |   8 +-
 .claude/epics/reset-all/110.md                     |   8 +-
 .claude/epics/reset-all/111.md                     |  15 ++-
 lib/components/components.dart                     |   1 +
 lib/components/popups/confirmation_dialog.dart     | 110 ++++++++++++++++
 lib/components/popups/edit_source_popup.dart       |  54 ++++++--
 lib/providers/record_provider.dart                 |  19 ++-
 lib/repositories/record_repository.dart            |  19 ++-
 lib/screens/home/home_screen.dart                  |  35 +++++
 .../popups/confirmation_dialog_test.dart           | 131 +++++++++++++++++++
 test/components/popups/edit_source_popup_test.dart | 143 +++++++++++++++++++++
 test/models/record_test.dart                       |   5 +-
 test/providers/record_provider_test.dart           |  33 ++++-
 test/repositories/record_repository_test.dart      |  75 ++++++++++-
 test/screens/home/home_screen_test.dart            | 102 +++++++++++++++
 test/screens/home_screen_test.dart                 |  14 +-
 test/verification_test.dart                        |   4 +
 23 files changed, 792 insertions(+), 83 deletions(-)
```
