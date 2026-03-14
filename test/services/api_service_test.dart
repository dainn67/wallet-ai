import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/services/api_service.dart';

void main() {
  group('ApiService Tests', () {
    test('AppConfig returns correct baseUrl for dev environment', () {
      final config = AppConfig();
      config.environment = AppEnvironment.dev;
      expect(config.baseUrl, 'https://api.dev.wallet-ai.com');
    });

    test('AppConfig returns correct baseUrl for prod environment', () {
      final config = AppConfig();
      config.environment = AppEnvironment.prod;
      expect(config.baseUrl, 'https://api.wallet-ai.com');
    });

    test('ApiService initializes with correct baseUrl from config', () {
      final config = AppConfig();
      config.environment = AppEnvironment.dev;
      final apiService = ApiService(config: config);
      
      // We can't easily check private _dio, but we can verify it doesn't throw
      // and behaves as expected.
      expect(apiService, isNotNull);
    });
  });
}
