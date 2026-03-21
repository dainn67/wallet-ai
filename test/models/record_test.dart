import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/models/record.dart';

void main() {
  group('Record Model Tests', () {
    test('Record creation with null createdAt uses current timestamp', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = Record(
        moneySourceId: 1,
        amount: 100.0,
        currency: 'USD',
        description: 'Test record',
        type: 'expense',
      );
      
      // recordId and createdAt should be >= now
      expect(record.recordId, isNotNull);
      expect(record.createdAt, greaterThanOrEqualTo(now));
      expect(record.createdAt, equals(record.recordId));
    });

    test('Record.fromMap with timestamp correctly retrieved', () {
      final timestamp = 1711000000000;
      final map = {
        'record_id': 123,
        'created_at': timestamp,
        'money_source_id': 1,
        'category_id': 2,
        'amount': 50.0,
        'currency': 'VND',
        'description': 'Lunch',
        'type': 'expense',
      };
      
      final record = Record.fromMap(map);
      
      expect(record.recordId, 123);
      expect(record.createdAt, timestamp);
      expect(record.moneySourceId, 1);
      expect(record.categoryId, 2);
      expect(record.amount, 50.0);
      expect(record.currency, 'VND');
      expect(record.description, 'Lunch');
      expect(record.type, 'expense');
    });

    test('toMap handles created_at correctly', () {
      final timestamp = 1711000000000;
      final record = Record(
        recordId: 456,
        createdAt: timestamp,
        moneySourceId: 1,
        categoryId: 3,
        amount: 200.0,
        currency: 'USD',
        description: 'Salary',
        type: 'income',
      );
      
      final map = record.toMap();
      
      expect(map['record_id'], 456);
      expect(map['created_at'], timestamp);
      expect(map['money_source_id'], 1);
      expect(map['category_id'], 3);
      expect(map['amount'], 200.0);
      expect(map['currency'], 'USD');
      expect(map['description'], 'Salary');
      expect(map['type'], 'income');
    });
  });
}
