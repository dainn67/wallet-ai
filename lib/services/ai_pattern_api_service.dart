import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/services/services.dart';

class AiPatternApiService {
  static final AiPatternApiService _instance = AiPatternApiService._internal();
  static AiPatternApiService? _mockInstance;

  factory AiPatternApiService() => _mockInstance ?? _instance;
  AiPatternApiService._internal();

  @visibleForTesting
  static void setMockInstance(AiPatternApiService? instance) {
    _mockInstance = instance;
  }

  /// Triggers a background sync of AI patterns based on the last sync time.
  /// Should be called on app startup (e.g. from main.dart or Home).
  Future<void> syncPendingContexts() async {
    final storage = StorageService();
    final int lastSyncTime = storage.getInt(StorageService.keyLastContextSyncTime) ?? -1;
    final now = DateTime.now();

    DateTime? startDate;
    DateTime? endDate;
    bool isInitial = false;

    if (lastSyncTime == -1) {
      // First time sync -> 90 days. Leave start/end null but set isInitial.
      isInitial = true;
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59).subtract(const Duration(days: 1));
    } else {
      // Delta sync -> from last sync to yesterday
      final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSyncTime);
      final yesterday = DateTime(now.year, now.month, now.day, 23, 59, 59).subtract(const Duration(days: 1));

      // If we've already synced up to yesterday or today, nothing to do.
      if (lastSyncDate.isAfter(yesterday) || lastSyncDate.isAtSameMomentAs(yesterday)) {
        debugPrint('AiPatternApiService: Context already up to date.');
        return;
      }

      // Start is the day AFTER the last sync
      startDate = DateTime(lastSyncDate.year, lastSyncDate.month, lastSyncDate.day).add(const Duration(days: 1));
      endDate = yesterday;
    }

    try {
      final contextPayload = await AiContextService().getAiContext(start: startDate, end: endDate, isInitial: isInitial);

      final token = AppConfig().patternSyncApiKey;
      final headers = {if (token.isNotEmpty) 'Authorization': 'Bearer $token'};

      debugPrint('AiPatternApiService: Syncing pattern from $startDate to $endDate');

      // POST to server pattern endpoint
      final responseStr = await ApiService().post('/api/patterns/sync', data: contextPayload, headers: headers);

      if (responseStr != null && responseStr.isNotEmpty) {
        // Assume JSON wrapper {"pattern": "..."} based on implementation plan open question
        String patternData = responseStr;
        try {
          final decoded = jsonDecode(responseStr);
          if (decoded is Map<String, dynamic> && decoded.containsKey('pattern')) {
            patternData = decoded['pattern'];
          }
        } catch (e) {
          debugPrint('AiPatternApiService: Response is not JSON, treating as raw string.');
        }

        // Save pattern and update sync time
        await storage.setString(StorageService.keyLongTermUserPattern, patternData);
        // Save the 'endDate' as the new sync watermark
        await storage.setInt(StorageService.keyLastContextSyncTime, endDate.millisecondsSinceEpoch);

        debugPrint('AiPatternApiService: Sync complete.');
      } else {
        debugPrint('AiPatternApiService: Sync empty response from server.');
      }
    } catch (e) {
      debugPrint('AiPatternApiService: Error syncing context: $e');
    }
  }
}
