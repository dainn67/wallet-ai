class Category {
  final int? categoryId;
  final String name;
  final String type; // 'income', 'expense', or 'transfer'
  final int parentId; // -1 for parent category
  final String emoji;

  Category({
    this.categoryId,
    required this.name,
    required this.type,
    this.parentId = -1,
    this.emoji = '🏷️',
  }) : assert(
          type == 'income' || type == 'expense' || type == 'transfer',
          'Type must be income, expense, or transfer',
        );

  Map<String, dynamic> toMap() {
    return {
      if (categoryId != null) 'category_id': categoryId,
      'name': name,
      'type': type,
      'parent_id': parentId,
      'emoji': emoji,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      categoryId: map['category_id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      parentId: (map['parent_id'] as int?) ?? -1,
      emoji: (map['emoji'] as String?)?.isNotEmpty == true ? map['emoji'] as String : '🏷️',
    );
  }

  Category copyWith({
    int? categoryId,
    String? name,
    String? type,
    int? parentId,
    String? emoji,
  }) {
    return Category(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      emoji: emoji ?? this.emoji,
    );
  }

  @override
  String toString() {
    return 'Category(categoryId: $categoryId, name: $name, type: $type, parentId: $parentId, emoji: $emoji)';
  }
}
