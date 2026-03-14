import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/services/api_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAppConfig extends Mock implements AppConfig {}

void main() {
  late MockAppConfig mockAppConfig;

  setUp(() {
    mockAppConfig = MockAppConfig();
    when(() => mockAppConfig.baseUrl).thenReturn('https://api.example.com');
    // Ensure the singleton is configured with the mock
    ApiService(config: mockAppConfig);
  });

  group('ApiService', () {
    test('singleton returns the same instance', () {
      final instance1 = ApiService();
      final instance2 = ApiService();
      expect(instance1, same(instance2));
    });
  });
}
