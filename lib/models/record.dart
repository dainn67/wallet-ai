import 'suggested_category.dart';

class Record {
  final int recordId;
  final int lastUpdated; // millisecondsSinceEpoch — audit (row last written)
  final int occurredAt;  // millisecondsSinceEpoch — event time (user-editable)
  final int moneySourceId;
  final int? targetSourceId; // non-null when this row is a transfer destination
  final int categoryId;
  final String? categoryName;
  final String? sourceName;
  final String? targetSourceName;
  final double amount;
  final String currency;
  final String description;
  final String type; // 'income', 'expense', or 'transfer'
  final SuggestedCategory? suggestedCategory; // transient — not persisted

  bool get isTransfer => type == 'transfer';

  /// Public entry point — ensures that when the caller omits both `lastUpdated`
  /// and `occurredAt` (the common case for a newly saved record with no time
  /// cue from the AI), both fields resolve to the *same* `DateTime.now()`.
  /// The private constructor does the field-final work.
  factory Record({
    int recordId = 0,
    int? lastUpdated,
    int? occurredAt,
    required int moneySourceId,
    int? targetSourceId,
    int categoryId = 1,
    String? categoryName,
    String? sourceName,
    String? targetSourceName,
    required double amount,
    required String currency,
    required String description,
    required String type,
    SuggestedCategory? suggestedCategory,
  }) {
    final resolvedLastUpdated = lastUpdated ?? DateTime.now().millisecondsSinceEpoch;
    return Record._(
      recordId: recordId,
      lastUpdated: resolvedLastUpdated,
      occurredAt: occurredAt ?? resolvedLastUpdated,
      moneySourceId: moneySourceId,
      targetSourceId: targetSourceId,
      categoryId: categoryId,
      categoryName: categoryName,
      sourceName: sourceName,
      targetSourceName: targetSourceName,
      amount: amount,
      currency: currency,
      description: description,
      type: type,
      suggestedCategory: suggestedCategory,
    );
  }

  Record._({
    required this.recordId,
    required this.lastUpdated,
    required this.occurredAt,
    required this.moneySourceId,
    required this.targetSourceId,
    required this.categoryId,
    required this.categoryName,
    required this.sourceName,
    required this.targetSourceName,
    required this.amount,
    required this.currency,
    required this.description,
    required this.type,
    required this.suggestedCategory,
  }) : assert(
          type == 'income' || type == 'expense' || type == 'transfer',
          'Type must be income, expense, or transfer',
        );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'last_updated': lastUpdated,
      'occurred_at': occurredAt,
      'money_source_id': moneySourceId,
      'target_source_id': targetSourceId,
      'category_id': categoryId,
      'amount': amount,
      'currency': currency,
      'description': description,
      'type': type,
    };
    if (recordId != 0) {
      map['record_id'] = recordId;
    }
    return map;
  }

  factory Record.fromMap(Map<String, dynamic> map) {
    final lastUpdated = map['last_updated'] as int;
    return Record(
      recordId: map['record_id'] as int,
      lastUpdated: lastUpdated,
      // Fallback to last_updated if migration hasn't run yet (defensive — NFR-2).
      occurredAt: (map['occurred_at'] as int?) ?? lastUpdated,
      moneySourceId: map['money_source_id'] as int,
      targetSourceId: map['target_source_id'] as int?,
      categoryId: map['category_id'] as int? ?? 1,
      categoryName: map['category_name'] as String?,
      sourceName: map['source_name'] as String?,
      targetSourceName: map['target_source_name'] as String?,
      amount: (map['amount'] as num).toDouble(),
      currency: (map['currency'] as String).split('.').last.toUpperCase(),
      description: map['description'] as String,
      type: map['type'] as String,
    );
  }

  Record copyWith({
    int? recordId,
    int? lastUpdated,
    int? occurredAt,
    int? moneySourceId,
    int? targetSourceId,
    int? categoryId,
    String? categoryName,
    String? sourceName,
    String? targetSourceName,
    double? amount,
    String? currency,
    String? description,
    String? type,
    SuggestedCategory? suggestedCategory,
    bool clearSuggestedCategory = false,
    bool clearTargetSource = false,
  }) {
    return Record(
      recordId: recordId ?? this.recordId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      occurredAt: occurredAt ?? this.occurredAt,
      moneySourceId: moneySourceId ?? this.moneySourceId,
      targetSourceId: clearTargetSource ? null : (targetSourceId ?? this.targetSourceId),
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      sourceName: sourceName ?? this.sourceName,
      targetSourceName: clearTargetSource ? null : (targetSourceName ?? this.targetSourceName),
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      type: type ?? this.type,
      suggestedCategory: clearSuggestedCategory ? null : (suggestedCategory ?? this.suggestedCategory),
    );
  }

  @override
  String toString() {
    return 'Record(recordId: $recordId, lastUpdated: $lastUpdated, occurredAt: $occurredAt, moneySourceId: $moneySourceId, targetSourceId: $targetSourceId, categoryId: $categoryId, categoryName: $categoryName, sourceName: $sourceName, targetSourceName: $targetSourceName, amount: $amount, currency: $currency, description: $description, type: $type)';
  }
}
