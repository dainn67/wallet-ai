/// One scheduled reminder entry. Translation strings live in [L10nConfig] —
/// only the keys are referenced here so copy edits stay in the l10n file.
class ReminderConfig {
  final int notificationId;
  final String id;
  final int daysAfterLastRecord;
  final String titleKey;
  final String bodyKey;

  const ReminderConfig({
    required this.notificationId,
    required this.id,
    required this.daysAfterLastRecord,
    required this.titleKey,
    required this.bodyKey,
  });
}

/// Single source of truth for the inactivity-reminder ladder.
///
/// To add a new step (e.g. "day 14"), append one entry here and add the two
/// matching `notif_dayN_title` / `notif_dayN_body` keys to [L10nConfig].
class NotificationConfig {
  static const int fireHour = 20; // 8 PM local
  static const int fireMinute = 0;

  /// Stable channel id used on Android.
  static const String channelId = 'wally_inactivity_reminders';
  static const String channelName = 'Inactivity reminders';
  static const String channelDescription =
      'Gentle nudges to log expenses after a few quiet days.';

  static const int testNotificationId = 9000;

  static const List<ReminderConfig> inactivityReminders = [
    ReminderConfig(
      notificationId: 1001,
      id: 'inactivity_day_1',
      daysAfterLastRecord: 1,
      titleKey: 'notif_day1_title',
      bodyKey: 'notif_day1_body',
    ),
    ReminderConfig(
      notificationId: 1003,
      id: 'inactivity_day_3',
      daysAfterLastRecord: 3,
      titleKey: 'notif_day3_title',
      bodyKey: 'notif_day3_body',
    ),
    ReminderConfig(
      notificationId: 1005,
      id: 'inactivity_day_5',
      daysAfterLastRecord: 5,
      titleKey: 'notif_day5_title',
      bodyKey: 'notif_day5_body',
    ),
    ReminderConfig(
      notificationId: 1007,
      id: 'inactivity_day_7',
      daysAfterLastRecord: 7,
      titleKey: 'notif_day7_title',
      bodyKey: 'notif_day7_body',
    ),
  ];
}
