# Typography

This document outlines the font configuration and usage for the Wally AI application.

## Overview
The application uses the **Poppins** font family as its primary and only typeface. To ensure offline support, fast rendering, and consistent design across all platforms, the font is served via local assets rather than network fetching.

## Technical Implementation

### Local Asset Configuration
The Poppins font family is registered in `pubspec.yaml` with all 18 available weights and styles (Thin 100 to Black 900, including italics).

**File Path:** `assets/fonts/Poppins-*.ttf`

**Registration Example:**
```yaml
fonts:
  - family: Poppins
    fonts:
      - asset: assets/fonts/Poppins-Thin.ttf
        weight: 100
      ...
```

### Global Application
The font is applied globally via the app's `ThemeData` in `lib/main.dart`:

```dart
theme: ThemeData(
  fontFamily: 'Poppins',
  textTheme: const TextTheme().apply(fontFamily: 'Poppins'),
  // ... other theme properties
)
```

### Usage in UI
All `Text` widgets automatically inherit the Poppins font from the global theme. Developers should use standard `TextStyle` or `Theme.of(context).textTheme` styles without explicitly specifying `fontFamily`.

**Preferred Usage:**
```dart
Text(
  'Example',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontWeight: FontWeight.w600,
  ),
)
```

**Custom Style (if needed):**
```dart
style: const TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
)
```

## Maintenance
- **Adding new weights:** Ensure the TTF file is added to `assets/fonts/` and registered correctly in `pubspec.yaml`.
- **Replacing Font Family:** Update the `fonts` section in `pubspec.yaml`, the `fontFamily` in `lib/main.dart`, and the `apply` call on `textTheme`.

## Constraints
- **google_fonts package:** This package is **PROHIBITED** to ensure full offline support and prevent network-related rendering delays (FOUT). Use only local assets.
