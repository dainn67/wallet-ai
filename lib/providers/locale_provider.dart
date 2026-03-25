import 'package:flutter/foundation.dart';
import '../configs/l10n_config.dart';
import '../services/storage_service.dart';

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
      try {
        _language = AppLanguage.values.firstWhere(
          (e) => e.toString() == langStr,
        );
      } catch (_) {
        _language = AppLanguage.english;
      }
    }

    final currStr = _storageService.getString(_keyCurrency);
    if (currStr != null) {
      try {
        _currency = AppCurrency.values.firstWhere(
          (e) => e.toString() == currStr,
        );
      } catch (_) {
        _currency = AppCurrency.usd;
      }
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    await _storageService.setString(_keyLanguage, lang.toString());
    notifyListeners();
  }

  Future<void> setCurrency(AppCurrency curr) async {
    if (_currency == curr) return;
    _currency = curr;
    await _storageService.setString(_keyCurrency, curr.toString());
    notifyListeners();
  }

  String translate(String key) {
    return L10nConfig.getTranslation(_language, key);
  }
}
