class Category {
  final int? categoryId;
  final String name;
  final String type; // 'income' or 'expense'

  Category({
    this.categoryId,
    required this.name,
    required this.type,
  }) : assert(type == 'income' || type == 'expense', 'Type must be income or expense');

  Map<String, dynamic> toMap() {
    return {
      if (categoryId != null) 'category_id': categoryId,
      'name': name,
      'type': type,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      categoryId: map['category_id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
    );
  }

  Category copyWith({
    int? categoryId,
    String? name,
    String? type,
  }) {
    return Category(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'Category(categoryId: $categoryId, name: $name, type: $type)';
  }
}
