import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:wallet_ai/configs/configs.dart';

/// Wraps `flutter_local_notifications` for inactivity-reminder scheduling.
///
/// Singleton — follow the existing service pattern. Call [init] in `main()`
/// before `runApp` so the plugin (and its TZ database) is ready before any
/// provider tries to schedule.
///
/// All copy comes from [L10nConfig]; the reminder ladder comes from
/// [NotificationConfig]. The service never hardcodes either — adding a new
/// step or tweaking a string requires zero changes here.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService? _mockInstance;

  factory NotificationService() => _mockInstance ?? _instance;

  NotificationService._internal();

  @visibleForTesting
  static void setMockInstance(NotificationService? instance) {
    _mockInstance = instance;
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;

    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      debugPrint('[NotificationService] Failed to detect local TZ: $e');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      // Permission is asked explicitly via [requestPermission] so the user
      // sees the prompt on first launch, not during init.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      // Show notifications while the app is in the foreground.
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    _initialised = true;
  }

  /// Asks the OS for notification permission. Returns whether it was granted.
  /// Safe to call repeatedly — the OS only prompts the first time; subsequent
  /// calls return the existing status without surfacing UI.
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Whether the OS currently allows the app to post notifications.
  Future<bool> isPermissionGranted() async {
    return Permission.notification.isGranted;
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  /// Cancels any pending reminders and schedules a fresh ladder of nudges
  /// computed from [lastActivityAt] (the user's most recent app activity, e.g.
  /// the latest `Record.lastUpdated`). Past fire times are silently skipped so
  /// scheduling at 9 PM doesn't emit a "day 1" nudge that should have fired
  /// an hour ago.
  ///
  /// Caller is expected to gate this behind the user's "Reminders" toggle.
  Future<void> scheduleInactivityReminders({
    required DateTime lastActivityAt,
    required String Function(String key) translate,
  }) async {
    if (!_initialised) await init();
    await cancelAllReminders();

    final now = tz.TZDateTime.now(tz.local);

    for (final r in NotificationConfig.inactivityReminders) {
      final fireAt = _fireTimeFor(lastActivityAt, r.daysAfterLastRecord);
      if (!fireAt.isAfter(now)) continue;

      await _plugin.zonedSchedule(
        r.notificationId,
        translate(r.titleKey),
        translate(r.bodyKey),
        fireAt,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: r.id,
      );
    }
  }

  /// Schedules the full reminder ladder using seconds instead of days.
  /// Mirrors the real inactivity flow so the scheduling pipeline (AlarmManager
  /// → ScheduledNotificationReceiver → NotificationManager) is fully exercised.
  /// Day-1/3/5/7 reminders fire at +1s / +3s / +5s / +7s from now.
  Future<void> scheduleTestReminders({
    required String Function(String key) translate,
  }) async {
    if (!_initialised) await init();
    await cancelAllReminders();

    final now = tz.TZDateTime.now(tz.local);
    for (final r in NotificationConfig.inactivityReminders) {
      final fireAt = now.add(Duration(seconds: r.daysAfterLastRecord));
      await _plugin.zonedSchedule(
        r.notificationId,
        translate(r.titleKey),
        translate(r.bodyKey),
        fireAt,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: r.id,
      );
    }
  }

  /// Cancels only the inactivity-reminder ladder, leaving any future
  /// non-reminder notifications (e.g. budget alerts) untouched.
  Future<void> cancelAllReminders() async {
    if (!_initialised) await init();
    for (final r in NotificationConfig.inactivityReminders) {
      await _plugin.cancel(r.notificationId);
    }
  }

  // ---------- internal ----------

  tz.TZDateTime _fireTimeFor(DateTime lastActivityAt, int daysAfter) {
    final local = tz.TZDateTime.from(lastActivityAt, tz.local);
    return tz.TZDateTime(
      tz.local,
      local.year,
      local.month,
      local.day + daysAfter,
      NotificationConfig.fireHour,
      NotificationConfig.fireMinute,
    );
  }

  NotificationDetails _notificationDetails() {
    const android = AndroidNotificationDetails(
      NotificationConfig.channelId,
      NotificationConfig.channelName,
      channelDescription: NotificationConfig.channelDescription,
      // High importance = heads-up banner on Android; default only shows in shade.
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }
}
