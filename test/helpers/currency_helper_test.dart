import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_ai/helpers/currency_helper.dart';
import 'package:wallet_ai/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('CurrencyHelper.format', () {
    test('formats VND correctly (dot for thousands, comma for decimals)', () async {
      // Explicitly set to VND for this test
      await StorageService().setString(StorageService.keyCurrency, 'VND');
      expect(CurrencyHelper.format(1234567.89), '1.234.567,89');
      expect(CurrencyHelper.format(1000), '1.000');
    });

    test('formats USD correctly (comma for thousands, dot for decimals)', () async {
      await StorageService().setString(StorageService.keyCurrency, 'USD');
      expect(CurrencyHelper.format(1234567.89), '1,234,567.89');
      expect(CurrencyHelper.format(1000), '1,000');
    });

    test('formats with explicit currency parameter', () {
      expect(CurrencyHelper.format(1234567.89, currency: 'VND'), '1.234.567,89');
      expect(CurrencyHelper.format(1234567.89, currency: 'USD'), '1,234,567.89');
    });
  });
}
