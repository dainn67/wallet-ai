import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/services/chat_api_service.dart';

class MockAppConfig extends Mock implements AppConfig {}

void main() {
  late MockAppConfig mockAppConfig;

  setUp(() {
    mockAppConfig = MockAppConfig();
    when(() => mockAppConfig.baseUrl).thenReturn('https://api.test.com');
    when(() => mockAppConfig.mainChatApiKey).thenReturn('test_key');
    // Ensure the singleton is configured with the mock
    ChatApiService(config: mockAppConfig);
  });

  group('ChatApiService', () {
    test('singleton returns the same instance', () {
      final instance1 = ChatApiService();
      final instance2 = ChatApiService();
      expect(instance1, same(instance2));
    });
  });
}
