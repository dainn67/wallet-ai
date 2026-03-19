import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/chat_api_service.dart';

void main() {
  group('ChatApiService formatting helpers', () {
    test('formatMoneySources returns correctly formatted string', () {
      final sources = [
        MoneySource(sourceId: 1, sourceName: 'Bank', amount: 1000),
        MoneySource(sourceId: 2, sourceName: 'Wallet', amount: 50),
      ];
      final result = ChatApiService.formatMoneySources(sources);
      expect(result, '1-Bank, 2-Wallet');
    });

    test('formatMoneySources handles empty list', () {
      final result = ChatApiService.formatMoneySources([]);
      expect(result, 'No money sources available');
    });

    test('formatCategories returns correctly formatted string', () {
      final categories = [
        Category(categoryId: 1, name: 'Food', type: 'expense'),
        Category(categoryId: 2, name: 'Salary', type: 'income'),
      ];
      final result = ChatApiService.formatCategories(categories);
      expect(result, '1-Food, 2-Salary');
    });

    test('formatCategories handles empty list', () {
      final result = ChatApiService.formatCategories([]);
      expect(result, 'No categories available');
    });
  });
}
