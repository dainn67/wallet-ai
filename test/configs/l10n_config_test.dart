import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/configs/l10n_config.dart';

void main() {
  group('L10nConfig Tests', () {
    test('All languages should have the same set of keys', () {
      final languages = AppLanguage.values;
      if (languages.isEmpty) return;

      final firstLanguageKeys = L10nConfig.translations[languages.first]!.keys.toSet();

      for (var i = 1; i < languages.length; i++) {
        final currentLanguageKeys = L10nConfig.translations[languages[i]]!.keys.toSet();
        expect(currentLanguageKeys, equals(firstLanguageKeys), 
          reason: 'Language ${languages[i]} does not have the same keys as ${languages.first}');
      }
    });

    test('Currency symbols should be defined for all AppCurrency values', () {
      for (final currency in AppCurrency.values) {
        expect(L10nConfig.currencySymbols.containsKey(currency), isTrue);
        expect(L10nConfig.currencySymbols[currency], isNotEmpty);
      }
    });

    test('Currency codes should be defined for all AppCurrency values', () {
      for (final currency in AppCurrency.values) {
        expect(L10nConfig.currencyCodes.containsKey(currency), isTrue);
        expect(L10nConfig.currencyCodes[currency], isNotEmpty);
      }
    });

    test('getTranslation returns the correct string or the key if not found', () {
      expect(L10nConfig.getTranslation(AppLanguage.english, 'drawer_records'), 'Records');
      expect(L10nConfig.getTranslation(AppLanguage.vietnamese, 'drawer_records'), 'Ghi chép');
      expect(L10nConfig.getTranslation(AppLanguage.english, 'non_existent_key'), 'non_existent_key');
    });
  });
}
