class Record {
  final int recordId;
  final int createdAt; // millisecondsSinceEpoch
  final int moneySourceId;
  final double amount;
  final String currency;
  final String description;
  final String type; // 'income' or 'expense'

  Record({
    int? recordId,
    int? createdAt,
    required this.moneySourceId,
    required this.amount,
    required this.currency,
    required this.description,
    required this.type,
  })  : assert(type == 'income' || type == 'expense', 'Type must be income or expense'),
        recordId = recordId ?? DateTime.now().millisecondsSinceEpoch,
        createdAt = createdAt ?? recordId ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'record_id': recordId,
      'created_at': createdAt,
      'money_source_id': moneySourceId,
      'amount': amount,
      'currency': currency,
      'description': description,
      'type': type,
    };
  }

  factory Record.fromMap(Map<String, dynamic> map) {
    return Record(
      recordId: map['record_id'] as int,
      createdAt: map['created_at'] as int,
      moneySourceId: map['money_source_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String,
      description: map['description'] as String,
      type: map['type'] as String,
    );
  }

  Record copyWith({
    int? recordId,
    int? createdAt,
    int? moneySourceId,
    double? amount,
    String? currency,
    String? description,
    String? type,
  }) {
    return Record(
      recordId: recordId ?? this.recordId,
      createdAt: createdAt ?? this.createdAt,
      moneySourceId: moneySourceId ?? this.moneySourceId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'Record(recordId: $recordId, createdAt: $createdAt, moneySourceId: $moneySourceId, amount: $amount, currency: $currency, description: $description, type: $type)';
  }
}
