class MoneySource {
  final int? sourceId;
  final String sourceName;

  MoneySource({
    this.sourceId,
    required this.sourceName,
  });

  Map<String, dynamic> toMap() {
    return {
      if (sourceId != null) 'source_id': sourceId,
      'source_name': sourceName,
    };
  }

  factory MoneySource.fromMap(Map<String, dynamic> map) {
    return MoneySource(
      sourceId: map['source_id'] as int?,
      sourceName: map['source_name'] as String,
    );
  }

  MoneySource copyWith({
    int? sourceId,
    String? sourceName,
  }) {
    return MoneySource(
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
    );
  }
}
