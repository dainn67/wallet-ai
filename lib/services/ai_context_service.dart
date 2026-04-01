import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/services.dart';
import 'package:wallet_ai/services/storage_service.dart';

class AiContextService {
  /// Singleton instance of [AiContextService].
  static final AiContextService _instance = AiContextService._internal();
  static AiContextService? _mockInstance;

  /// Returns the singleton instance of [AiContextService].
  factory AiContextService() => _mockInstance ?? _instance;
  AiContextService._internal();

  /// Sets a mock instance for testing purposes.
  @visibleForTesting
  static void setMockInstance(AiContextService? instance) {
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
  /// Combines amount and currency to save tokens (e.g. "20USD").
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

  /// Builds a summary of income/expenses aggregated by category and source.
  Map<String, dynamic> _buildSummary(List<Record> records, int periodDays) {
    double totalIncome = 0;
    double totalExpense = 0;
    final byCategory = <String, double>{};
    final byMoneySource = <String, double>{};

    for (final record in records) {
      if (record.type == 'income') {
        totalIncome += record.amount;
      } else {
        totalExpense += record.amount;
        final category = _extractCategoryName(record.categoryName);
        byCategory[category] = (byCategory[category] ?? 0) + record.amount;
        final source = record.sourceName ?? 'Unknown';
        byMoneySource[source] = (byMoneySource[source] ?? 0) + record.amount;
      }
    }

    return {'period_days': periodDays, 'total_income': totalIncome, 'total_expense': totalExpense, 'by_category': byCategory, 'by_money_source': byMoneySource};
  }

  /// Fetches and packages data into a context map for the AI to analyze.
  /// [start] and [end] can define an exact sync window.
  /// If not provided, [isInitial] determines the default window (90d for initial, 1d for daily).
  Future<Map<String, dynamic>> getAiContext({DateTime? start, DateTime? end, bool isInitial = false}) async {
    final now = DateTime.now();

    // 1. Determine the record boundaries
    DateTime recordStartDate;
    DateTime recordEndDate = end ?? now;

    if (start != null) {
      recordStartDate = start;
    } else {
      recordStartDate = isInitial ? now.subtract(const Duration(days: 90)) : now.subtract(const Duration(hours: 24));
    }

    // 2. Summary window is the larger of the record window or 30 days trailing from end
    final int recordWindowDays = recordEndDate.difference(recordStartDate).inDays;
    // Always summarize at least 30 days for context, unless Initial sync which matches its window exactly
    final int summaryDays = isInitial ? recordWindowDays : (recordWindowDays > 30 ? recordWindowDays : 30);

    final DateTime summaryStartDate = recordEndDate.subtract(Duration(days: summaryDays));

    final allRecords = await RecordRepository().getAllRecords();

    final windowRecords = allRecords.where((r) {
      return r.lastUpdated >= recordStartDate.millisecondsSinceEpoch && r.lastUpdated <= recordEndDate.millisecondsSinceEpoch;
    }).toList();

    final summaryRecords = allRecords.where((r) {
      return r.lastUpdated >= summaryStartDate.millisecondsSinceEpoch && r.lastUpdated <= recordEndDate.millisecondsSinceEpoch;
    }).toList();

    final records = windowRecords.map(_recordToMap).toList();
    final summary = _buildSummary(summaryRecords, summaryDays);

    final clientMetadata = {'current_time': DateFormat('HH:mm d MMM yyyy').format(now), 'currency': StorageService().getString(StorageService.keyCurrency) ?? 'USD'};

    return {'client_metadata': clientMetadata, 'records': records, 'summary': summary};
  }

  /// Triggers a background sync of AI patterns based on the last sync time.
  /// Should be called on app startup (e.g. from main.dart).
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
        debugPrint('AiContextService: Context already up to date.');
        return;
      }

      // Start is the day AFTER the last sync
      startDate = DateTime(lastSyncDate.year, lastSyncDate.month, lastSyncDate.day).add(const Duration(days: 1));
      endDate = yesterday;
    }

    try {
      final contextPayload = await getAiContext(start: startDate, end: endDate, isInitial: isInitial);

      final token = AppConfig().patternSyncApiKey;
      final headers = {if (token.isNotEmpty) 'Authorization': 'Bearer $token'};

      debugPrint('AiContextService: Syncing pattern from $startDate to $endDate');

      // Wrap in 'inputs' field like ChatApiService style
      final payload = {'inputs': contextPayload};

      // POST to the new single-question endpoint
      final responseStr = await ApiService().post('/api/single-question/walletai-analyze-pattern', data: payload, headers: headers);

      if (responseStr != null && responseStr.isNotEmpty) {
        String patternData = responseStr;
        try {
          final decoded = jsonDecode(responseStr);
          // Match standard Dify/API response style: checking both 'answer' and 'pattern'
          if (decoded is Map<String, dynamic>) {
            patternData = decoded['message'] ?? decoded['pattern'] ?? responseStr;
          }
        } catch (e) {
          debugPrint('AiContextService: Response is not JSON, treating as raw string.');
        }

        // Save pattern and update sync time
        await storage.setString(StorageService.keyLongTermUserPattern, patternData);
        await storage.setInt(StorageService.keyLastContextSyncTime, endDate.millisecondsSinceEpoch);

        debugPrint('AiContextService: Sync complete.');
      } else {
        debugPrint('AiContextService: Sync empty response from server.');
      }
    } catch (e) {
      debugPrint('AiContextService: Error syncing context: $e');
    }
  }
}
