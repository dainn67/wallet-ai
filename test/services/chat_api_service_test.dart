import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/services/api_service.dart';
import 'package:wallet_ai/services/chat_api_service.dart';

class _MockApiService extends Mock implements ApiService {}

void main() {
  late _MockApiService mockApi;
  late Object? capturedBody;

  setUpAll(() {
    // ChatApiService reads `ApiConfig().mainChatApiKey`, which touches dotenv.
    // Seed dotenv so the getter returns an empty string instead of throwing.
    dotenv.testLoad(fileInput: '');
  });

  setUp(() {
    mockApi = _MockApiService();
    capturedBody = null;

    ApiService.setMockInstance(mockApi);

    when(() => mockApi.postStream(
          any(),
          data: any(named: 'data'),
          token: any(named: 'token'),
          headers: any(named: 'headers'),
        )).thenAnswer((invocation) async {
      capturedBody = invocation.namedArguments[#data];
      // Empty stream — we only inspect the outbound body here.
      return (stream: Stream<String>.empty(), statusCode: 200, detail: null);
    });
  });

  tearDown(() {
    ApiService.setMockInstance(null);
  });

  Future<void> drain(Stream<dynamic> s) => s.drain();

  test('streamChat without imagesBase64 produces body with no images key', () async {
    await drain(ChatApiService().streamChat('hello'));

    expect(capturedBody, isA<Map>());
    final body = capturedBody as Map;
    expect(body.containsKey('images'), isFalse);
    expect(body['query'], 'hello');
  });

  test('streamChat with empty imagesBase64 list omits the images key (backward compat)', () async {
    await drain(ChatApiService().streamChat('hi', imagesBase64: const []));

    final body = capturedBody as Map;
    expect(body.containsKey('images'), isFalse);
    expect(body['query'], 'hi');
  });

  test('streamChat with non-empty imagesBase64 includes top-level images key', () async {
    await drain(ChatApiService().streamChat('lunch', imagesBase64: const ['abc']));

    final body = capturedBody as Map;
    expect(body['images'], const ['abc']);
    expect(body['query'], 'lunch');
    // Critical: images must be top-level, NOT nested inside `inputs` (AD-2).
    final inputs = body['inputs'] as Map;
    expect(inputs.containsKey('images'), isFalse);
  });

  test('streamChat with empty caption and images sends empty query plus images', () async {
    await drain(ChatApiService().streamChat('', imagesBase64: const ['abc', 'def']));

    final body = capturedBody as Map;
    expect(body['query'], '');
    expect(body['images'], const ['abc', 'def']);
  });

  // audio field tests (AD-2 voice extension)
  group('audio field', () {
    test('streamChat without audioBase64 produces body with no audio key', () async {
      await drain(ChatApiService().streamChat('hello'));

      final body = capturedBody as Map;
      expect(body.containsKey('audio'), isFalse);
      expect(body['query'], 'hello');
    });

    test('streamChat with empty audioBase64 omits the audio key', () async {
      await drain(ChatApiService().streamChat('', audioBase64: ''));

      final body = capturedBody as Map;
      expect(body.containsKey('audio'), isFalse);
    });

    test('streamChat with non-empty audioBase64 includes top-level audio key', () async {
      await drain(ChatApiService().streamChat('', audioBase64: 'abc123=='));

      final body = capturedBody as Map;
      expect(body['audio'], 'abc123==');
      expect(body['query'], '');
      // Critical: audio must be top-level, NOT nested inside `inputs` (AD-2).
      final inputs = body['inputs'] as Map;
      expect(inputs.containsKey('audio'), isFalse);
    });

    test('streamChat with audioBase64 and non-empty query includes both', () async {
      await drain(ChatApiService().streamChat('lunch 50k', audioBase64: 'abc123=='));

      final body = capturedBody as Map;
      expect(body['audio'], 'abc123==');
      expect(body['query'], 'lunch 50k');
    });

    test('regression: streamChat with imagesBase64 has images key and no audio key', () async {
      await drain(ChatApiService().streamChat('hello', imagesBase64: const ['imgdata']));

      final body = capturedBody as Map;
      expect(body['images'], const ['imgdata']);
      expect(body.containsKey('audio'), isFalse);
    });
  });
}
