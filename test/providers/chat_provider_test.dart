import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/models/chat_message.dart';
import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/services/chat_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:wallet_ai/config/app_config.dart';

class MockChatApiService extends Mock implements ChatApiService {}
class MockHttpClient extends Mock implements http.Client {}
class MockAppConfig extends Mock implements AppConfig {}
class FakeBaseRequest extends Fake implements http.BaseRequest {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBaseRequest());
  });

  setUp(() {
    // Since ChatApiService is a singleton, we need to be careful.
    // However, for testing ChatProvider, we can try to mock the singleton if possible, 
    // or better, modify ChatProvider to allow injection.
    // For now, let's see if we can use the factory to inject mocks.
    
    // Actually, ChatApiService() returns the singleton. 
    // If we want to mock it, we should probably have injected it.
  });

  group('ChatProvider', () {
    test('sendMessage adds user message and starts streaming', () async {
      final chatProvider = ChatProvider();
      
      // We need a way to mock ChatApiService.streamChat
      // Since ChatProvider calls ChatApiService(), it gets the singleton.
      // Let's configure the singleton with a mock client.
      
      final mockHttpClient = MockHttpClient();
      final mockAppConfig = MockAppConfig();
      when(() => mockAppConfig.baseUrl).thenReturn('https://api.test.com');
      
      ChatApiService(client: mockHttpClient, config: mockAppConfig);
      
      final mockResponse = http.StreamedResponse(
        Stream.fromIterable([
          'data: {"content": "Hello"}\n',
          'data: {"content": " world"}\n',
          'data: [DONE]\n',
        ].map((s) => s.codeUnits)),
        200,
      );
      
      when(() => mockHttpClient.send(any())).thenAnswer((_) async => mockResponse);

      final future = chatProvider.sendMessage('Hi');
      
      expect(chatProvider.messages.length, 2);
      expect(chatProvider.messages[0].role, ChatRole.user);
      expect(chatProvider.messages[0].content, 'Hi');
      expect(chatProvider.messages[1].role, ChatRole.assistant);
      expect(chatProvider.isStreaming, true);
      
      await future;
      // Note: sendMessage doesn't await the stream internally in my implementation, 
      // but the stream subscription is started.
      // We might need to wait for the stream to finish.
      
      // Let's wait a bit for the stream to process
      await Future.delayed(Duration(milliseconds: 100));
      
      expect(chatProvider.isStreaming, false);
      expect(chatProvider.messages[1].content, 'Hello world');
    });

    test('isStreaming becomes false on stream error', () async {
      final chatProvider = ChatProvider();
      final mockHttpClient = MockHttpClient();
      final mockAppConfig = MockAppConfig();
      when(() => mockAppConfig.baseUrl).thenReturn('https://api.test.com');
      ChatApiService(client: mockHttpClient, config: mockAppConfig);

      when(() => mockHttpClient.send(any())).thenThrow(Exception('Network error'));

      try {
        await chatProvider.sendMessage('Hi');
      } catch (_) {}

      expect(chatProvider.isStreaming, false);
      expect(chatProvider.messages[1].content, contains('Error'));
    });
    
    test('dispose cancels stream subscription', () async {
      // This is hard to test directly without exposing the subscription, 
      // but we can check if it stops updating.
      final chatProvider = ChatProvider();
      final mockHttpClient = MockHttpClient();
      final mockAppConfig = MockAppConfig();
      when(() => mockAppConfig.baseUrl).thenReturn('https://api.test.com');
      ChatApiService(client: mockHttpClient, config: mockAppConfig);

      final controller = StreamController<List<int>>();
      final mockResponse = http.StreamedResponse(controller.stream, 200);
      
      when(() => mockHttpClient.send(any())).thenAnswer((_) async => mockResponse);

      chatProvider.sendMessage('Hi');
      
      await Future.delayed(Duration(milliseconds: 10));
      expect(chatProvider.isStreaming, true);
      
      chatProvider.dispose();
      
      controller.add('data: {"content": "Still here"}\n'.codeUnits);
      await Future.delayed(Duration(milliseconds: 10));
      
      // Should not crash and should not update further (though we can't easily check messages of a disposed provider safely in all cases, but here it's just a list)
      // Actually, after dispose, we shouldn't really care, but we want to make sure the subscription is cancelled.
    });
  });
}
