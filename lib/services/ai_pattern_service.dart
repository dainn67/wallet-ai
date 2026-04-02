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

  /// Fetches and packages data into a context snapshot for the AI to analyze.
  /// [start] and [end] can define an exact window.
  Future<Map<String, dynamic>> _generateContextSnapshot({DateTime? start, DateTime? end, bool isInitial = false}) async {
    final now = DateTime.now();

    DateTime recordStartDate;
    DateTime recordEndDate = end ?? now;

    if (start != null) {
      recordStartDate = start;
    } else {
      recordStartDate = isInitial ? now.subtract(const Duration(days: 90)) : now.subtract(const Duration(hours: 24));
    }

    final int recordWindowDays = recordEndDate.difference(recordStartDate).inDays;
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

  /// Updates the user pattern in storage by sending data to the AI server.
  /// Triggered on app startup or manually from test UI.
  /// Use [force] to bypass the daily update check during testing.
  Future<void> updateUserPattern({bool force = false}) async {
    final storage = StorageService();
    final int lastUpdateTime = storage.getInt(StorageService.keyLastPatternUpdateTime) ?? -1;
    final now = DateTime.now();

    DateTime? startDate;
    DateTime? endDate;
    bool isInitial = false;

    if (lastUpdateTime == -1) {
      // First time -> 90 days.
      isInitial = true;
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59).subtract(const Duration(days: 1));
    } else {
      final lastUpdateDate = DateTime.fromMillisecondsSinceEpoch(lastUpdateTime);
      final yesterday = DateTime(now.year, now.month, now.day, 23, 59, 59).subtract(const Duration(days: 1));

      if (!force && (lastUpdateDate.isAfter(yesterday) || lastUpdateDate.isAtSameMomentAs(yesterday))) {
        debugPrint('AiPatternService: Pattern already updated today.');
        return;
      }

      startDate = DateTime(lastUpdateDate.year, lastUpdateDate.month, lastUpdateDate.day).add(const Duration(days: 1));
      endDate = yesterday;
    }

    try {
      final contextPayload = await _generateContextSnapshot(start: startDate, end: endDate, isInitial: isInitial);
      final token = ApiConfig().patternSyncApiKey;
      final headers = {if (token.isNotEmpty) 'Authorization': 'Bearer $token'};

      debugPrint('AiPatternService: Requesting pattern update from $startDate to $endDate');

      final payload = {
        'user': 'system_sync',
        'query': 'Analyze my spending pattern from ${startDate ?? "beginning"} to ${endDate ?? "yesterday"}',
        'inputs': contextPayload,
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
        await storage.setInt(StorageService.keyLastPatternUpdateTime, endDate.millisecondsSinceEpoch);
        debugPrint('AiPatternService: User pattern updated.');
      }
    } catch (e) {
      debugPrint('AiPatternService: Error updating pattern: $e');
    }
  }
}
