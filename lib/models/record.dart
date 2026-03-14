class Record {
  final int? recordId;
  final int moneySourceId;
  final double amount;
  final String currency;
  final String description;
  final String type; // 'income' or 'expense'

  Record({
    this.recordId,
    required this.moneySourceId,
    required this.amount,
    required this.currency,
    required this.description,
    required this.type,
  }) : assert(type == 'income' || type == 'expense', 'Type must be income or expense');

  Map<String, dynamic> toMap() {
    return {
      if (recordId != null) 'record_id': recordId,
      'money_source_id': moneySourceId,
      'amount': amount,
      'currency': currency,
      'description': description,
      'type': type,
    };
  }

  factory Record.fromMap(Map<String, dynamic> map) {
    return Record(
      recordId: map['record_id'] as int?,
      moneySourceId: map['money_source_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String,
      description: map['description'] as String,
      type: map['type'] as String,
    );
  }

  Record copyWith({
    int? recordId,
    int? moneySourceId,
    double? amount,
    String? currency,
    String? description,
    String? type,
  }) {
    return Record(
      recordId: recordId ?? this.recordId,
      moneySourceId: moneySourceId ?? this.moneySourceId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      type: type ?? this.type,
    );
  }
}
