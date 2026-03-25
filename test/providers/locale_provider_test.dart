import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/configs/l10n_config.dart';
import 'package:wallet_ai/providers/locale_provider.dart';
import 'package:wallet_ai/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  late LocaleProvider localeProvider;
  late MockStorageService mockStorageService;

  setUp(() {
    mockStorageService = MockStorageService();
    // Default mock behavior for getString
    when(() => mockStorageService.getString(any())).thenReturn(null);
    when(() => mockStorageService.setString(any(), any())).thenAnswer((_) async => true);
    
    localeProvider = LocaleProvider(mockStorageService);
  });

  group('LocaleProvider', () {
    test('initial state is default when storage is empty', () {
      expect(localeProvider.language, AppLanguage.english);
      expect(localeProvider.currency, AppCurrency.usd);
    });

    test('loads settings from storage on initialization', () {
      when(() => mockStorageService.getString('user_language')).thenReturn(AppLanguage.vietnamese.toString());
      when(() => mockStorageService.getString('user_currency')).thenReturn(AppCurrency.vnd.toString());

      // Create a new instance to trigger _loadFromStorage
      final provider = LocaleProvider(mockStorageService);

      expect(provider.language, AppLanguage.vietnamese);
      expect(provider.currency, AppCurrency.vnd);
    });

    test('setLanguage updates state, notifies listeners, and persists', () async {
      bool notified = false;
      localeProvider.addListener(() => notified = true);

      await localeProvider.setLanguage(AppLanguage.vietnamese);

      expect(localeProvider.language, AppLanguage.vietnamese);
      expect(notified, true);
      verify(() => mockStorageService.setString('user_language', AppLanguage.vietnamese.toString())).called(1);
    });

    test('setCurrency updates state, notifies listeners, and persists', () async {
      bool notified = false;
      localeProvider.addListener(() => notified = true);

      await localeProvider.setCurrency(AppCurrency.vnd);

      expect(localeProvider.currency, AppCurrency.vnd);
      expect(notified, true);
      verify(() => mockStorageService.setString('user_currency', AppCurrency.vnd.toString())).called(1);
    });

    test('translate returns correct values', () async {
      // Assuming 'tab_home' exists in both English and Vietnamese translations
      expect(localeProvider.translate('tab_home'), L10nConfig.translations[AppLanguage.english]!['tab_home']);

      await localeProvider.setLanguage(AppLanguage.vietnamese);
      expect(localeProvider.translate('tab_home'), L10nConfig.translations[AppLanguage.vietnamese]!['tab_home']);
    });
    
    test('translate returns key when translation is missing', () {
      expect(localeProvider.translate('non_existent_key'), 'non_existent_key');
    });
  });
}
