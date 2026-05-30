import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/notification_service.dart';
import 'package:wallet_ai/services/storage_service.dart';

import 'locale_provider.dart';
import 'record_provider.dart';

/// Coordinates the persisted "Reminders enabled" toggle with
/// [NotificationService] scheduling.
///
/// Registered as a [ChangeNotifierProxyProvider2] over [RecordProvider] and
/// [LocaleProvider] in `main.dart`, so its `update` callback fires whenever
/// the user's records or chosen language change. We use that to re-apply the
/// reminder schedule (single source of truth: `_reapply`).
///
/// UI binds via `context.watch<NotificationProvider>().enabled` and toggles
/// via `context.read<NotificationProvider>().setEnabled(...)`.
class NotificationProvider with ChangeNotifier {
  final StorageService _storageService;

  bool _enabled = false;
  RecordProvider? _recordProvider;
  LocaleProvider? _localeProvider;

  NotificationProvider(this._storageService) {
    _enabled = _storageService.getBool(StorageService.keyRemindersEnabled) ?? false;
  }

  bool get enabled => _enabled;

  /// Whether the OS permission prompt has been shown once. Used by `main()`
  /// to fire the prompt exactly once on first launch.
  bool get permissionAlreadyAsked =>
      _storageService.getBool(StorageService.keyRemindersPermissionAsked) ?? false;

  Future<void> markPermissionAsked() async {
    await _storageService.setBool(StorageService.keyRemindersPermissionAsked, true);
  }

  /// Called from `main.dart`'s proxy-provider update. Stores references and
  /// re-applies the reminder schedule.
  void attach({RecordProvider? records, LocaleProvider? locale}) {
    _recordProvider = records;
    _localeProvider = locale;
    // Fire-and-forget — UI shouldn't block on scheduling.
    unawaited(_reapply());
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) {
      // Still re-apply: lets the drawer "refresh" the schedule even when the
      // toggle didn't change (rare, harmless).
      await _reapply();
      return;
    }
    _enabled = value;
    await _storageService.setBool(StorageService.keyRemindersEnabled, value);
    notifyListeners();
    await _reapply();
  }

  Future<void> _reapply() async {
    final records = _recordProvider?.records ?? const <Record>[];
    final locale = _localeProvider;

    if (!_enabled || records.isEmpty || locale == null) {
      await NotificationService().cancelAllReminders();
      return;
    }

    final latestOccurredAt = records
        .map((r) => r.occurredAt)
        .reduce((a, b) => a > b ? a : b);

    await NotificationService().scheduleInactivityReminders(
      lastRecordAt: DateTime.fromMillisecondsSinceEpoch(latestOccurredAt),
      translate: locale.translate,
    );
  }
}
