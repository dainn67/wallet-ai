import 'package:flutter/material.dart';

/// Shows a dialog to select the application currency.
/// Returns the selected currency string ('VND' or 'USD'), or null if dismissed.
Future<String?> showCurrencySelectionPopup({
  required BuildContext context,
  required String currentCurrency,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: const Text('Select Currency'),
        children: [
          RadioListTile<String>(
            title: const Text('VND'),
            value: 'VND',
            groupValue: currentCurrency,
            onChanged: (value) {
              if (value != null) {
                Navigator.pop(context, value);
              }
            },
          ),
          RadioListTile<String>(
            title: const Text('USD'),
            value: 'USD',
            groupValue: currentCurrency,
            onChanged: (value) {
              if (value != null) {
                Navigator.pop(context, value);
              }
            },
          ),
        ],
      );
    },
  );
}
