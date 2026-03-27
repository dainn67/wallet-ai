import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/models/category.dart';

void main() {
  group('Category Model', () {
    test('should create a Category with default parentId', () {
      final category = Category(name: 'Food', type: 'expense');
      expect(category.name, 'Food');
      expect(category.type, 'expense');
      expect(category.parentId, -1);
    });

    test('should create a Category with specific parentId', () {
      final category = Category(name: 'Lunch', type: 'expense', parentId: 1);
      expect(category.parentId, 1);
    });

    test('toMap should include parent_id', () {
      final category = Category(categoryId: 1, name: 'Food', type: 'expense', parentId: -1);
      final map = category.toMap();
      expect(map['category_id'], 1);
      expect(map['name'], 'Food');
      expect(map['type'], 'expense');
      expect(map['parent_id'], -1);
    });

    test('fromMap should handle parent_id', () {
      final map = {
        'category_id': 1,
        'name': 'Lunch',
        'type': 'expense',
        'parent_id': 2,
      };
      final category = Category.fromMap(map);
      expect(category.categoryId, 1);
      expect(category.name, 'Lunch');
      expect(category.type, 'expense');
      expect(category.parentId, 2);
    });

    test('fromMap should default parent_id to -1 if missing', () {
      final map = {
        'category_id': 1,
        'name': 'Lunch',
        'type': 'expense',
      };
      final category = Category.fromMap(map);
      expect(category.parentId, -1);
    });

    test('copyWith should update parentId', () {
      final category = Category(name: 'Food', type: 'expense');
      final subCategory = category.copyWith(parentId: 1, name: 'Lunch');
      expect(subCategory.name, 'Lunch');
      expect(subCategory.parentId, 1);
      expect(subCategory.type, 'expense');
    });

    test('toString should include parentId', () {
      final category = Category(name: 'Food', type: 'expense', parentId: -1);
      expect(category.toString(), contains('parentId: -1'));
    });
  });
}
