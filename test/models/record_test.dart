import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/models/suggested_category.dart';

void main() {
  group('Record Model Tests', () {
    test('Record creation with null lastUpdated uses current timestamp', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = Record(
        moneySourceId: 1,
        amount: 100.0,
        currency: 'USD',
        description: 'Test record',
        type: 'expense',
      );
      
      // recordId should be 0 by default, and lastUpdated should be >= now
      expect(record.recordId, equals(0));
      expect(record.lastUpdated, greaterThanOrEqualTo(now));
    });

    test('Record.fromMap with timestamp correctly retrieved', () {
      final timestamp = 1711000000000;
      final map = {
        'record_id': 123,
        'last_updated': timestamp,
        'money_source_id': 1,
        'category_id': 2,
        'amount': 50.0,
        'currency': 'VND',
        'description': 'Lunch',
        'type': 'expense',
      };
      
      final record = Record.fromMap(map);
      
      expect(record.recordId, 123);
      expect(record.lastUpdated, timestamp);
      expect(record.moneySourceId, 1);
      expect(record.categoryId, 2);
      expect(record.amount, 50.0);
      expect(record.currency, 'VND');
      expect(record.description, 'Lunch');
      expect(record.type, 'expense');
    });

    test('toMap handles last_updated correctly', () {
      final timestamp = 1711000000000;
      final record = Record(
        recordId: 456,
        lastUpdated: timestamp,
        moneySourceId: 1,
        categoryId: 3,
        amount: 200.0,
        currency: 'USD',
        description: 'Salary',
        type: 'income',
      );
      
      final map = record.toMap();
      
      expect(map['record_id'], 456);
      expect(map['last_updated'], timestamp);
      expect(map['money_source_id'], 1);
      expect(map['category_id'], 3);
      expect(map['amount'], 200.0);
      expect(map['currency'], 'USD');
      expect(map['description'], 'Salary');
      expect(map['type'], 'income');
    });
  });

  group('Record suggestedCategory (transient field)', () {
    final sc = SuggestedCategory(
      name: 'Streaming',
      type: 'expense',
      parentId: -1,
      message: 'Create it?',
    );

    Record makeRecord({SuggestedCategory? suggestedCategory}) => Record(
          moneySourceId: 1,
          amount: 100.0,
          currency: 'USD',
          description: 'Test',
          type: 'expense',
          suggestedCategory: suggestedCategory,
        );

    test('toMap does not include suggested_category key', () {
      final record = makeRecord(suggestedCategory: sc);
      final map = record.toMap();
      expect(map.containsKey('suggested_category'), isFalse);
    });

    test('fromMap always has suggestedCategory == null', () {
      final map = {
        'record_id': 1,
        'last_updated': 1711000000000,
        'money_source_id': 1,
        'category_id': 1,
        'amount': 100.0,
        'currency': 'USD',
        'description': 'Test',
        'type': 'expense',
      };
      final record = Record.fromMap(map);
      expect(record.suggestedCategory, isNull);
    });

    test('copyWith(clearSuggestedCategory: true) sets field to null', () {
      final record = makeRecord(suggestedCategory: sc);
      final cleared = record.copyWith(clearSuggestedCategory: true);
      expect(cleared.suggestedCategory, isNull);
    });

    test('copyWith() with no args passes through suggestedCategory reference', () {
      final record = makeRecord(suggestedCategory: sc);
      final copy = record.copyWith();
      expect(identical(copy.suggestedCategory, sc), isTrue);
    });

    test('copyWith(suggestedCategory: newSc) updates field', () {
      final newSc = SuggestedCategory(
        name: 'Food',
        type: 'expense',
        parentId: -1,
        message: 'New',
      );
      final record = makeRecord(suggestedCategory: sc);
      final updated = record.copyWith(suggestedCategory: newSc);
      expect(updated.suggestedCategory, equals(newSc));
    });
  });
}
