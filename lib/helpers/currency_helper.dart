import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class CurrencyHelper {
  /// Formats a double amount based on the currency.
  /// VND: 1.234.567,89 (dot for thousands, comma for decimals)
  /// USD: 1,234,567.89 (comma for thousands, dot for decimals)
  static String format(double amount, {String? currency}) {
    try {
      final rawCurrency = currency ?? StorageService().getString(StorageService.keyCurrency) ?? 'VND';
      final effectiveCurrency = rawCurrency.toUpperCase();
      final isUSD = effectiveCurrency.contains('USD');

      // 1. Convert to string with max 2 decimals, removing trailing .00 if whole number
      String s = amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);

      // 2. Separate whole and decimal parts
      List<String> parts = s.split('.');
      String whole = parts[0];
      String decimal = parts.length > 1 ? parts[1] : '';

      // 3. Add thousand separator
      final thousandSeparator = isUSD ? ',' : '.';
      final decimalSeparator = isUSD ? '.' : ',';

      // Using a regex to find groups of 3 digits from the right
      final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      String formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]}$thousandSeparator');

      // 4. Combine with decimal separator
      String result = decimal.isEmpty ? formattedWhole : '$formattedWhole$decimalSeparator$decimal';
      
      // 5. Add currency symbol/code (optional but good for context, though task didn't specify)
      // For now, just follow the format requested.
      return result;
    } catch (e) {
      debugPrint('Error formatting currency: $e');
      return amount.toString();
    }
  }
}
