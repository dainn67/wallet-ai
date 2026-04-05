import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/services.dart';

class AiPatternService {
  /// Singleton instance of [AiPatternService].
  static final AiPatternService _instance = AiPatternService._internal();
  static AiPatternService? _mockInstance;

  /// Returns the singleton instance of [AiPatternService].
  factory AiPatternService() => _mockInstance ?? _instance;
  AiPatternService._internal();

  /// Sets a mock instance for testing purposes.
  @visibleForTesting
  static void setMockInstance(AiPatternService? instance) {
    _mockInstance = instance;
  }

  /// Extracts the specific sub-category name from a full category string.
  /// E.g. "Food - Dining Out" -> "Dining Out".
  String _extractCategoryName(String? categoryName) {
    if (categoryName == null) return 'Uncategorized';
    final parts = categoryName.split(' - ');
    return parts.last;
  }

  /// Transforms a [Record] into a concise map for AI context.
  Map<String, dynamic> _recordToMap(Record record) {
    final dt = DateTime.fromMillisecondsSinceEpoch(record.lastUpdated);
    return {
      'description': record.description,
      'amount': '${record.amount}${record.currency}',
      'category': _extractCategoryName(record.categoryName),
      'money_source': record.sourceName ?? 'Unknown',
      'datetime': DateFormat('HH:mm d MMM yyyy').format(dt),
    };
  }

  /// Fetches and packages data into a context snapshot for the AI to analyze.
  Future<Map<String, dynamic>> _generateContextSnapshot(DateTime latestStart, DateTime latestEnd) async {
    final now = DateTime.now();
    final currency = StorageService().getString(StorageService.keyCurrency) ?? 'USD';

    // 1. Calculate Timeframes
    // Momentum: 3 days before the start of the latest window
    final momentumEndDate = latestStart.subtract(const Duration(milliseconds: 1));
    final momentumStartDate = DateTime(latestStart.year, latestStart.month, latestStart.day).subtract(const Duration(days: 3));

    // 2. Fetch Data
    final recordRepo = RecordRepository();
    final allRecords = await recordRepo.getAllRecords();
    final allSources = await recordRepo.getAllMoneySources();

    final budgetRemaining = allSources.map((s) => '${s.amount}$currency from ${s.sourceName}').toList();

    // 3. Filter Records
    final latestRecords = allRecords
        .where((r) {
          final dt = DateTime.fromMillisecondsSinceEpoch(r.lastUpdated);
          return dt.isAfter(latestStart.subtract(const Duration(milliseconds: 1))) && dt.isBefore(latestEnd.add(const Duration(milliseconds: 1)));
        })
        .map(_recordToMap)
        .toList();

    final momentumRecords = allRecords
        .where((r) {
          final dt = DateTime.fromMillisecondsSinceEpoch(r.lastUpdated);
          return dt.isAfter(momentumStartDate.subtract(const Duration(milliseconds: 1))) && dt.isBefore(momentumEndDate.add(const Duration(milliseconds: 1)));
        })
        .map(_recordToMap)
        .toList();

    // 4. Build Structure
    return {
      'current_context': {
        'current_time': DateFormat('HH:mm').format(now),
        'day_of_week': DateFormat('E').format(now),
        'current_date': DateFormat('d MMM yyyy').format(now),
        'budget_remaining': budgetRemaining,
      },
      'latest_records': latestRecords,
      'recent_momentum': momentumRecords,
    };
  }

  /// Updates the user pattern in storage by sending data to the AI server.
  /// Triggered on app startup or manually from test UI.
  /// Use [force] to bypass the daily update check during testing.
  Future<void> updateUserPattern({bool force = false}) async {
    final storage = StorageService();
    final int lastUpdateTime = storage.getInt(StorageService.keyLastPatternUpdateTime) ?? -1;
    final now = DateTime.now();

    // We effectively sync up to the very end of yesterday's data.
    final endOfYesterday = DateTime(now.year, now.month, now.day, 23, 59, 59).subtract(const Duration(days: 1));

    DateTime latestStart;
    DateTime latestEnd = endOfYesterday;

    if (lastUpdateTime == -1) {
      // First time -> 90 days.
      latestStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 90));
    } else {
      final lastUpdateDate = DateTime.fromMillisecondsSinceEpoch(lastUpdateTime);

      if (!force && (lastUpdateDate.isAfter(endOfYesterday) || lastUpdateDate.isAtSameMomentAs(endOfYesterday))) {
        debugPrint('AiPatternService: Pattern already updated for yesterday.');
        return;
      }
      latestStart = DateTime(lastUpdateDate.year, lastUpdateDate.month, lastUpdateDate.day).add(const Duration(days: 1));
    }

    try {
      final contextPayload = await _generateContextSnapshot(latestStart, latestEnd);
      final token = ApiConfig().patternSyncApiKey;
      final headers = {if (token.isNotEmpty) 'Authorization': 'Bearer $token'};

      debugPrint('AiPatternService: Requesting pattern update...');

      final currentPattern = storage.getString(StorageService.keyUserPattern) ?? '';

      final payload = {
        'inputs': {'recent_context': contextPayload, 'current_pattern': currentPattern},
      };

      final responseStr = await ApiService().post(ApiConfig.updateUserPatternPath, data: payload, headers: headers);

      if (responseStr != null && responseStr.isNotEmpty) {
        String patternData = responseStr;
        try {
          final decoded = jsonDecode(responseStr);
          if (decoded is Map<String, dynamic>) {
            patternData = decoded['message'] ?? decoded['pattern'] ?? responseStr;
          }
        } catch (_) {}

        await storage.setString(StorageService.keyUserPattern, patternData);
        // Save the end of yesterday as the new sync watermark
        await storage.setInt(StorageService.keyLastPatternUpdateTime, endOfYesterday.millisecondsSinceEpoch);
        debugPrint('AiPatternService: User pattern updated.');
      }
    } catch (e) {
      debugPrint('AiPatternService: Error updating pattern: $e');
    }
  }
}
