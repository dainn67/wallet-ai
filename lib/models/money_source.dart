class MoneySource {
  final int? sourceId;
  final String sourceName;
  final double amount;

  MoneySource({
    this.sourceId,
    required this.sourceName,
    this.amount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (sourceId != null) 'source_id': sourceId,
      'source_name': sourceName,
      'amount': amount,
    };
  }

  factory MoneySource.fromMap(Map<String, dynamic> map) {
    return MoneySource(
      sourceId: map['source_id'] as int?,
      sourceName: map['source_name'] as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  MoneySource copyWith({
    int? sourceId,
    String? sourceName,
    double? amount,
  }) {
    return MoneySource(
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      amount: amount ?? this.amount,
    );
  }
}
