class SuggestedCategory {
  final String name;
  final String type; // 'expense' or 'income'
  final int parentId; // -1 for top-level
  final String message;

  const SuggestedCategory({
    required this.name,
    required this.type,
    required this.parentId,
    required this.message,
  });

  static SuggestedCategory? fromJson(dynamic json) {
    try {
      if (json is! Map<String, dynamic>) return null;
      final name = json['name'] as String?;
      if (name == null || name.isEmpty) return null;
      final rawType = json['type'] as String?;
      if (rawType != 'expense' && rawType != 'income') return null;
      final type = rawType!;
      final parentId = (json['parent_id'] as num?)?.toInt() ?? -1;
      final message = json['message'] as String? ?? '';
      return SuggestedCategory(name: name, type: type, parentId: parentId, message: message);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() {
    return 'SuggestedCategory(name: $name, type: $type, parentId: $parentId, message: $message)';
  }
}
