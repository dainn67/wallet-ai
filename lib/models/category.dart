class Category {
  final int? categoryId;
  final String name;
  final String type; // 'income' or 'expense'
  final int parentId; // -1 for parent category

  Category({
    this.categoryId,
    required this.name,
    required this.type,
    this.parentId = -1,
  }) : assert(type == 'income' || type == 'expense', 'Type must be income or expense');

  Map<String, dynamic> toMap() {
    return {
      if (categoryId != null) 'category_id': categoryId,
      'name': name,
      'type': type,
      'parent_id': parentId,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      categoryId: map['category_id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      parentId: (map['parent_id'] as int?) ?? -1,
    );
  }

  Category copyWith({
    int? categoryId,
    String? name,
    String? type,
    int? parentId,
  }) {
    return Category(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  String toString() {
    return 'Category(categoryId: $categoryId, name: $name, type: $type, parentId: $parentId)';
  }
}
