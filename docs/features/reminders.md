# Reminders (Local Notifications)

Gentle nudges to log expenses after a few quiet days. The user can disable them anytime from the drawer.

## User Experience

- **First launch**: the OS permission prompt fires exactly once. If granted, the toggle defaults ON; if denied, OFF.
- **Drawer entry**: a `SwitchListTile` labeled *Reminders* in the menu drawer. Reactive — bound via `Consumer<NotificationProvider>`.
- **Re-enabling after revoke**: tapping the toggle ON when system permission is denied opens a `ConfirmationDialog` ("Notifications are off" / "Open Settings"). Confirming opens the OS settings page; the toggle does **not** flip.
- **Anchor**: schedule is computed from the user's most recent `Record.occurredAt`.
- **Fire time**: 20:00 (8 PM) local, **inexact** (~±15 min). The app intentionally avoids `SCHEDULE_EXACT_ALARM` so it doesn't qualify as an alarm-clock app under Play Store policy.

## Reminder ladder

| Day | English title | Vietnamese title |
|----:|---------------|------------------|
| 1   | What did you spend on today? | Hôm nay bạn chi gì rồi? |
| 3   | Catch me up on the week so far? | Cập nhật vài ngày qua nhé? |
| 5   | Five days of quiet | Năm ngày rồi không thấy ghi |
| 7   | Been a week — all good? | Đã một tuần — bạn ổn không? |

Tone is first-person from "Wally" (the AI assistant), conversational, no guilt-tripping.

## File Map

| Concern | Location |
|---|---|
| Reminder ladder (data) | `lib/configs/notification_config.dart` — `List<ReminderConfig>` |
| Localized copy | `lib/configs/l10n_config.dart` — `notif_dayN_title` / `notif_dayN_body` |
| Scheduling | `lib/services/notification_service.dart` — singleton, wraps `flutter_local_notifications` + `permission_handler` |
| Toggle state | `lib/providers/notification_provider.dart` — `ChangeNotifierProxyProvider2<RecordProvider, LocaleProvider, NotificationProvider>` |
| Persistence | `lib/services/storage_service.dart` — `keyRemindersEnabled`, `keyRemindersPermissionAsked` |
| First-launch ask | `lib/main.dart` — `_maybeAskNotificationPermissionOnce` |
| Drawer toggle | `lib/screens/home/home_screen.dart` — `_handleRemindersToggle` |

## Adding a new reminder step

1. Append a `ReminderConfig` entry to `NotificationConfig.inactivityReminders`.
2. Add the matching `notif_dayN_title` + `notif_dayN_body` keys to both languages in `L10nConfig.translations`.
3. No service or provider changes needed — `NotificationService` iterates the list.

## Activity anchor

The schedule is computed from the **latest `Record.lastUpdated`**, not `occurredAt`. `lastUpdated` is the row's audit timestamp (when it was written); `occurredAt` is user-editable event time. Anchoring on `lastUpdated` means back-dating a record (logging an old expense) does NOT collapse the reminder cadence — the user just engaged with the app, so the next nudge waits a full day.

## Known UX edge cases (v1)

- **Re-enabling after revoke**: if the user denies in OS settings, returns to the app, and taps the toggle ON, our dialog routes them to system settings. After enabling permission they must **return to the app and tap the toggle again** — we don't auto-re-check on app resume in v1.
- **App open without logging**: opening the app is NOT treated as activity. Only writing a record resets the cadence. This matches the user spec ("days since last *record*").
- **Latency**: scheduling uses `inexactAllowWhileIdle` → fire window is ~±15 min around 20:00 local. Acceptable for an end-of-day nudge; intentionally avoided to stay off Play Store's alarm-app allowlist.

## Triggers for re-scheduling

`NotificationProvider._reapply()` runs whenever any of these change:

- A record is created / updated / deleted (RecordProvider notifies → proxy `update` fires).
- The user switches language (LocaleProvider notifies → proxy `update` fires).
- The user flips the toggle (`setEnabled` calls `_reapply`).
- App start (`attach` is invoked on first provider build).

Each call cancels all pending notifications and re-schedules the ladder from the current latest `occurredAt`. Past fire times are skipped silently.

## Android Manifest

Required permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

`SCHEDULE_EXACT_ALARM` is deliberately omitted — see "Fire time" above.

## iOS

No `Info.plist` entry required for local notifications. Permission is requested at runtime via `permission_handler`.
