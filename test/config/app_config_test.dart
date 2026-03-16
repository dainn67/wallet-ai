import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/configs/app_config.dart';

void main() {
  group('AppConfig', () {
    test('default environment is dev (when no dart-define is provided)', () {
      final config = AppConfig();
      // Since we are running tests normally, it should default to 'dev'
      // unless flutter test is called with --dart-define=ENVIRONMENT=prod
      const envStr = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');

      if (envStr == 'prod') {
        expect(config.environment, AppEnvironment.prod);
        expect(config.baseUrl, 'https://api.wallet-ai.com');
      } else {
        expect(config.environment, AppEnvironment.dev);
        expect(config.baseUrl, 'https://api.dev.wallet-ai.com');
      }
    });

    test('timeouts are correctly set', () {
      final config = AppConfig();
      expect(config.connectTimeout.inSeconds, 10);
      expect(config.receiveTimeout.inSeconds, 10);
    });
  });
}
