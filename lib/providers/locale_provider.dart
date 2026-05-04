import 'package:flutter/foundation.dart';

import 'package:wallet_ai/configs/l10n_config.dart';
import 'package:wallet_ai/services/storage_service.dart';

class LocaleProvider with ChangeNotifier {
  static const String _keyLanguage = 'user_language';
  static const String _keyCurrency = 'user_currency';

  final StorageService _storageService;

  AppLanguage _language = AppLanguage.english;
  AppCurrency _currency = AppCurrency.usd;

  LocaleProvider(this._storageService) {
    _loadFromStorage();
  }

  AppLanguage get language => _language;
  AppCurrency get currency => _currency;

  void _loadFromStorage() {
    final langStr = _storageService.getString(_keyLanguage);
    if (langStr != null) {
      _language = AppLanguage.values.firstWhere(
        (e) => e.toString() == langStr || e.name == langStr,
        orElse: () => AppLanguage.english,
      );
    } else {
      // First launch — follow device locale, then persist so it sticks.
      final deviceLang = PlatformDispatcher.instance.locale.languageCode;
      _language = deviceLang == 'vi' ? AppLanguage.vietnamese : AppLanguage.english;
      _storageService.setString(_keyLanguage, _language.name);
    }

    final currStr = _storageService.getString(_keyCurrency);
    if (currStr != null) {
      _currency = AppCurrency.values.firstWhere(
        (e) => e.toString() == currStr || e.name == currStr || L10nConfig.currencyCodes[e] == currStr,
        orElse: () => AppCurrency.usd,
      );
    } else {
      _currency = _language == AppLanguage.vietnamese ? AppCurrency.vnd : AppCurrency.usd;
      final code = L10nConfig.currencyCodes[_currency] ?? 'USD';
      _storageService.setString(_keyCurrency, code);
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    await _storageService.setString(_keyLanguage, lang.name);
    notifyListeners();
  }

  Future<void> setCurrency(AppCurrency curr) async {
    if (_currency == curr) return;
    _currency = curr;
    final code = L10nConfig.currencyCodes[curr] ?? 'VND';
    await _storageService.setString(_keyCurrency, code);
    notifyListeners();
  }

  String translate(String key) {
    return L10nConfig.translations[_language]?[key] ?? key;
  }
}
