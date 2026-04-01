import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/storage_service.dart';

class AiContextService {
  static final AiContextService _instance = AiContextService._internal();
  static AiContextService? _mockInstance;

  factory AiContextService() => _mockInstance ?? _instance;
  AiContextService._internal();

  @visibleForTesting
  static void setMockInstance(AiContextService? instance) {
    _mockInstance = instance;
  }

  String _getTimeOfDay(int millisSinceEpoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millisSinceEpoch);
    final hour = dt.hour;
    if (hour >= 5 && hour <= 10) return 'Morning';
    if (hour >= 11 && hour <= 16) return 'Afternoon';
    if (hour >= 17 && hour <= 21) return 'Evening';
    return 'Night';
  }

  String _extractCategoryName(String? categoryName) {
    if (categoryName == null) return 'Uncategorized';
    final parts = categoryName.split(' - ');
    return parts.last;
  }

  Map<String, dynamic> _recordToMap(Record record) {
    final dt = DateTime.fromMillisecondsSinceEpoch(record.lastUpdated);
    return {
      'description': record.description,
      'amount': record.amount,
      'currency': record.currency,
      'type': record.type,
      'category': _extractCategoryName(record.categoryName),
      'money_source': record.sourceName ?? 'Unknown',
      'time_of_day': _getTimeOfDay(record.lastUpdated),
      'datetime': DateFormat('HH:mm d MMM yyyy').format(dt),
    };
  }

  Map<String, dynamic> _buildSummary(List<Record> records, int periodDays) {
    double totalIncome = 0;
    double totalExpense = 0;
    final byCategory = <String, double>{};
    final byTimeOfDay = <String, double>{};
    final byMoneySource = <String, double>{};

    for (final record in records) {
      if (record.type == 'income') {
        totalIncome += record.amount;
      } else {
        totalExpense += record.amount;
        final category = _extractCategoryName(record.categoryName);
        byCategory[category] = (byCategory[category] ?? 0) + record.amount;
        final timeOfDay = _getTimeOfDay(record.lastUpdated);
        byTimeOfDay[timeOfDay] = (byTimeOfDay[timeOfDay] ?? 0) + record.amount;
        final source = record.sourceName ?? 'Unknown';
        byMoneySource[source] = (byMoneySource[source] ?? 0) + record.amount;
      }
    }

    return {
      'period_days': periodDays,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'by_category': byCategory,
      'by_time_of_day': byTimeOfDay,
      'by_money_source': byMoneySource,
    };
  }

  Future<Map<String, dynamic>> buildSnapshot({bool isInitial = false}) async {
    final now = DateTime.now();
    final recordCutoff =
        isInitial ? now.subtract(const Duration(days: 90)) : now.subtract(const Duration(hours: 24));
    final summaryCutoff =
        isInitial ? recordCutoff : now.subtract(const Duration(days: 30));

    final allRecords = await RecordRepository().getAllRecords();

    final windowRecords = allRecords
        .where((r) => r.lastUpdated >= recordCutoff.millisecondsSinceEpoch)
        .toList();
    final summaryRecords = allRecords
        .where((r) => r.lastUpdated >= summaryCutoff.millisecondsSinceEpoch)
        .toList();

    final records = windowRecords.map(_recordToMap).toList();
    final summary = _buildSummary(summaryRecords, isInitial ? 90 : 30);

    final clientMetadata = {
      'sync_type': isInitial ? 'initial' : 'daily',
      'current_time': DateFormat('HH:mm d MMM yyyy').format(now),
      'timezone': now.timeZoneName,
      'language': StorageService().getString('user_language') ?? 'en',
      'currency': StorageService().getString(StorageService.keyCurrency) ?? 'USD',
    };

    return {
      'client_metadata': clientMetadata,
      'records': records,
      'summary': summary,
    };
  }
}
