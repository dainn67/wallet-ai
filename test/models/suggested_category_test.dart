import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/models/suggested_category.dart';

void main() {
  group('SuggestedCategory.fromJson', () {
    test('valid full JSON returns populated instance', () {
      final result = SuggestedCategory.fromJson({
        'name': 'Streaming',
        'type': 'expense',
        'parent_id': -1,
        'message': 'Create it?',
      });
      expect(result, isNotNull);
      expect(result!.name, 'Streaming');
      expect(result.type, 'expense');
      expect(result.parentId, -1);
      expect(result.message, 'Create it?');
    });

    test('missing name key returns null', () {
      final result = SuggestedCategory.fromJson({
        'type': 'expense',
        'parent_id': -1,
        'message': 'x',
      });
      expect(result, isNull);
    });

    test('empty name returns null', () {
      final result = SuggestedCategory.fromJson({
        'name': '',
        'type': 'expense',
        'parent_id': -1,
        'message': 'x',
      });
      expect(result, isNull);
    });

    test('type is other returns null', () {
      final result = SuggestedCategory.fromJson({
        'name': 'X',
        'type': 'other',
        'parent_id': -1,
        'message': 'x',
      });
      expect(result, isNull);
    });

    test('type is income returns non-null', () {
      final result = SuggestedCategory.fromJson({
        'name': 'Salary',
        'type': 'income',
        'parent_id': -1,
        'message': 'x',
      });
      expect(result, isNotNull);
      expect(result!.type, 'income');
    });

    test('parent_id missing defaults to -1', () {
      final result = SuggestedCategory.fromJson({
        'name': 'Food',
        'type': 'expense',
        'message': 'x',
      });
      expect(result, isNotNull);
      expect(result!.parentId, -1);
    });

    test('null input returns null without throwing', () {
      expect(() => SuggestedCategory.fromJson(null), returnsNormally);
      expect(SuggestedCategory.fromJson(null), isNull);
    });

    test('string input returns null without throwing', () {
      expect(() => SuggestedCategory.fromJson('bad string'), returnsNormally);
      expect(SuggestedCategory.fromJson('bad string'), isNull);
    });

    test('empty map returns null', () {
      expect(SuggestedCategory.fromJson({}), isNull);
    });

    test('completely malformed nested value returns null without throwing', () {
      expect(
        () => SuggestedCategory.fromJson({'name': 'X', 'type': 123, 'parent_id': 'bad'}),
        returnsNormally,
      );
      expect(SuggestedCategory.fromJson({'name': 'X', 'type': 123, 'parent_id': 'bad'}), isNull);
    });
  });
}
