# Perf Notes: epic/category-icons (NFR-2)

Target: ≤5ms first-frame regression on RecordsTab and CategoriesTab.

## Methodology
- Build: `fvm flutter run --profile` on a release-mode physical device.
- Capture first-frame from DevTools Performance.
- 10 cold opens per tab; record mean and std-dev.

## Results

| Build | RecordsTab first-frame (mean ms) | CategoriesTab first-frame (mean ms) |
|---|---|---|
| pre-#215 (parent commit on epic/category-icons) | TBD | TBD |
| post-#215 (this branch) | TBD | TBD |

Δ RecordsTab: TBD ms
Δ CategoriesTab: TBD ms

## Visual QA (NFR-3)

- iOS screenshots: `screenshots-ios/` (TBD)
- Android screenshots: `screenshots-android/` (TBD)
- Pass criterion: no tofu / missing-glyph anywhere; AD-5 emojis + 🏷️ render natively on both platforms.

## Status

Manual QA pending — see #216 (Integration verification & cleanup) for sign-off.
