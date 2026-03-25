enum AppLanguage { english, vietnamese }

enum AppCurrency { usd, vnd }

class L10nConfig {
  static const Map<AppLanguage, Map<String, String>> translations = {
    AppLanguage.english: {
      'drawer_records': 'Records',
      'drawer_chat': 'Chat',
      'drawer_settings': 'Settings',
      'reset_all_data': 'Reset All Data',
      'confirm_delete_source': 'Are you sure you want to delete this source?',
      'tab_home': 'Home',
      'tab_stats': 'Statistics',
      'popup_ok': 'OK',
      'popup_cancel': 'Cancel',
      'popup_confirm': 'Confirm',
    },
    AppLanguage.vietnamese: {
      'drawer_records': 'Ghi chép',
      'drawer_chat': 'Trò chuyện',
      'drawer_settings': 'Cài đặt',
      'reset_all_data': 'Đặt lại tất cả dữ liệu',
      'confirm_delete_source': 'Bạn có chắc chắn muốn xóa nguồn này không?',
      'tab_home': 'Trang chủ',
      'tab_stats': 'Thống kê',
      'popup_ok': 'OK',
      'popup_cancel': 'Hủy',
      'popup_confirm': 'Xác nhận',
    },
  };

  static const Map<AppCurrency, String> currencySymbols = {
    AppCurrency.usd: '\$',
    AppCurrency.vnd: '₫',
  };

  static const Map<AppCurrency, String> currencyCodes = {
    AppCurrency.usd: 'USD',
    AppCurrency.vnd: 'VND',
  };

  static String getTranslation(AppLanguage language, String key) {
    return translations[language]?[key] ?? key;
  }
}
