class MoneySource {
  final int? sourceId;
  final String sourceName;
  final double total;

  MoneySource({
    this.sourceId,
    required this.sourceName,
    this.total = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (sourceId != null) 'source_id': sourceId,
      'source_name': sourceName,
      'total': total,
    };
  }

  factory MoneySource.fromMap(Map<String, dynamic> map) {
    return MoneySource(
      sourceId: map['source_id'] as int?,
      sourceName: map['source_name'] as String,
      total: (map['total'] as num?)?.toDouble() ?? 0,
    );
  }

  MoneySource copyWith({
    int? sourceId,
    String? sourceName,
    double? total,
  }) {
    return MoneySource(
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      total: total ?? this.total,
    );
  }
}
