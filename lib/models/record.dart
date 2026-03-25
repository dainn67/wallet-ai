class Record {
  final int recordId;
  final int lastUpdated; // millisecondsSinceEpoch
  final int moneySourceId;
  final int categoryId;
  final String? categoryName;
  final String? sourceName;
  final double amount;
  final String currency;
  final String description;
  final String type; // 'income' or 'expense'

  Record({
    this.recordId = 0,
    int? lastUpdated,
    required this.moneySourceId,
    this.categoryId = 1, // Default to Uncategorized
    this.categoryName,
    this.sourceName,
    required this.amount,
    required this.currency,
    required this.description,
    required this.type,
  })  : assert(type == 'income' || type == 'expense', 'Type must be income or expense'),
        lastUpdated = lastUpdated ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    final map = {
      'last_updated': lastUpdated,
      'money_source_id': moneySourceId,
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
    return Record(
      recordId: map['record_id'] as int,
      lastUpdated: map['last_updated'] as int,
      moneySourceId: map['money_source_id'] as int,
      categoryId: map['category_id'] as int? ?? 1,
      categoryName: map['category_name'] as String?,
      sourceName: map['source_name'] as String?,
      amount: (map['amount'] as num).toDouble(),
      currency: (map['currency'] as String).split('.').last.toUpperCase(),
      description: map['description'] as String,
      type: map['type'] as String,
    );
  }

  Record copyWith({
    int? recordId,
    int? lastUpdated,
    int? moneySourceId,
    int? categoryId,
    String? categoryName,
    String? sourceName,
    double? amount,
    String? currency,
    String? description,
    String? type,
  }) {
    return Record(
      recordId: recordId ?? this.recordId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      moneySourceId: moneySourceId ?? this.moneySourceId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      sourceName: sourceName ?? this.sourceName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'Record(recordId: $recordId, lastUpdated: $lastUpdated, moneySourceId: $moneySourceId, categoryId: $categoryId, categoryName: $categoryName, sourceName: $sourceName, amount: $amount, currency: $currency, description: $description, type: $type)';
  }
}
