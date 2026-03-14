import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/services/api_exception.dart';
import 'package:wallet_ai/services/chat_api_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockAppConfig extends Mock implements AppConfig {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

void main() {
  late ChatApiService chatApiService;
  late MockHttpClient mockHttpClient;
  late MockAppConfig mockAppConfig;

  setUpAll(() {
    registerFallbackValue(FakeBaseRequest());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockAppConfig = MockAppConfig();
    when(() => mockAppConfig.baseUrl).thenReturn('https://api.test.com');
    chatApiService = ChatApiService(
      client: mockHttpClient,
      config: mockAppConfig,
    );
  });

  group('ChatApiService', () {
    test('singleton returns the same instance', () {
      final instance1 = ChatApiService();
      final instance2 = ChatApiService();
      expect(instance1, same(instance2));
    });

    test('streamChat emits content tokens correctly', () async {
      final mockResponse = http.StreamedResponse(
        Stream.fromIterable([
          utf8.encode('data: {"content": "Hello"}\n'),
          utf8.encode('data: {"content": " world"}\n'),
          utf8.encode('data: [DONE]\n'),
        ]),
        200,
      );

      when(
        () => mockHttpClient.send(any()),
      ).thenAnswer((_) async => mockResponse);

      final stream = chatApiService.streamChat('Hi');
      final result = await stream.toList();

      expect(result, ['Hello', ' world']);
      verify(() => mockHttpClient.send(any())).called(1);
    });

    test('streamChat handles non-JSON SSE data gracefully', () async {
      final mockResponse = http.StreamedResponse(
        Stream.fromIterable([
          utf8.encode('data: Hello\n'),
          utf8.encode('data:  world\n'),
          utf8.encode('data: [DONE]\n'),
        ]),
        200,
      );

      when(
        () => mockHttpClient.send(any()),
      ).thenAnswer((_) async => mockResponse);

      final stream = chatApiService.streamChat('Hi');
      final result = await stream.toList();

      expect(result, ['Hello', ' world']);
    });

    test('streamChat throws ApiException on error status code', () async {
      final mockResponse = http.StreamedResponse(
        Stream.fromIterable([
          utf8.encode(jsonEncode({'message': 'Invalid request'})),
        ]),
        400,
      );

      when(
        () => mockHttpClient.send(any()),
      ).thenAnswer((_) async => mockResponse);

      expect(
        () => chatApiService.streamChat('Hi').toList(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Invalid request'),
        ),
      );
    });

    test('streamChat throws ApiException on connection failure', () async {
      when(
        () => mockHttpClient.send(any()),
      ).thenThrow(Exception('Network error'));

      expect(
        () => chatApiService.streamChat('Hi').toList(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Network error'),
          ),
        ),
      );
    });
  });
}
