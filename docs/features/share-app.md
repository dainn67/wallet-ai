# Share App

## Overview

From the home drawer, **Share App** opens the platform share sheet with a short pitch and a Google Play link (App Store line is deferred until iOS is submitted).

## Technical flow

1. User taps **Share App** in `lib/screens/home/home_screen.dart`.
2. The shared string is `L10nConfig` key `share_app_message`, with `{android_url}` replaced by `AppConfig.androidPlayStoreUrl`. (App Store line is omitted until the iOS app is submitted; see `AppConfig` comments.)
3. `share_plus` `Share.share` sends the text; URLs are plain text so messaging apps typically linkify them.

## Configuration

Edit `lib/configs/app_config.dart`:

- **`androidPlayStoreUrl`** — must stay aligned with `applicationId` in `android/app/build.gradle.kts` (default uses `com.leslie.wallyai`).
- **iOS** — when the app is on the App Store, uncomment `iosAppStoreUrl` in `app_config.dart`, add an `App Store: {ios_url}` line back to `share_app_message` in `l10n_config.dart`, and substitute `{ios_url}` in `home_screen.dart` again.
