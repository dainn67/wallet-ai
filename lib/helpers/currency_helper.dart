import 'package:flutter/foundation.dart';

class CurrencyHelper {
  /// Formats a double amount with dot as thousand separator and comma as decimal separator.
  /// Example: 1234567.89 -> "1.234.567,89"
  /// Example: 1000 -> "1.000"
  static String format(double amount) {
    try {
      // 1. Convert to string with max 2 decimals, removing trailing .00 if whole number
      String s = amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
      
      // 2. Separate whole and decimal parts
      List<String> parts = s.split('.');
      String whole = parts[0];
      String decimal = parts.length > 1 ? parts[1] : '';
      
      // 3. Add dot thousand separator to 'whole' part
      // Using a regex to find groups of 3 digits from the right
      final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      String formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]}.');
      
      // 4. Combine with comma decimal separator
      return decimal.isEmpty ? formattedWhole : '$formattedWhole,$decimal';
    } catch (e) {
      debugPrint('Error formatting currency: $e');
      return amount.toString();
    }
  }
}
