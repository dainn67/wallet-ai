import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/services/services.dart';

class MockChatApiService extends Mock implements ChatApiService {}

class MockRecordProvider extends Mock implements RecordProvider {}

void main() {
  late ChatProvider chatProvider;
  late MockChatApiService mockChatApiService;
  late MockRecordProvider mockRecordProvider;

  setUp(() {
    mockChatApiService = MockChatApiService();
    mockRecordProvider = MockRecordProvider();

    ChatApiService.setMockInstance(mockChatApiService);

    chatProvider = ChatProvider(recordProvider: mockRecordProvider);

    registerFallbackValue(Record(
      moneySourceId: 1,
      amount: 0,
      currency: 'VND',
      description: '',
      type: 'expense',
    ));

    when(() => mockRecordProvider.createRecord(any())).thenAnswer((_) async => 1);
    when(() => mockRecordProvider.loadAll()).thenAnswer((_) async {});
    when(() => mockRecordProvider.categories).thenReturn([]);
    when(() => mockRecordProvider.moneySources).thenReturn([]);
  });

  tearDown(() {
    ChatApiService.setMockInstance(null);
  });

  // Helper: stub streamChat to return a one-shot stream with given response.
  void stubStream(String aiResponse) {
    when(() => mockChatApiService.streamChat(
          any(),
          conversationId: any(named: 'conversationId'),
          categoryList: any(named: 'categoryList'),
          moneySourceList: any(named: 'moneySourceList'),
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          pattern: any(named: 'pattern'),
          imagesBase64: any(named: 'imagesBase64'),
          audioBase64: any(named: 'audioBase64'),
        )).thenAnswer((_) async* {
      yield ChatStreamResponse(answer: aiResponse, messageId: 'msg-voice-test');
    });
  }

  group('FR-4 — audio pipeline', () {
    test('audio-only: non-empty audioBytes → audioBase64 forwarded, query is empty string', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      // base64([1,2,3]) == 'AQID'
      const expectedB64 = 'AQID';

      stubStream('Sure--//--[]');

      final future = chatProvider.sendMessage('', audioBytes: bytes);
      await future;

      verify(() => mockChatApiService.streamChat(
            '',
            conversationId: any(named: 'conversationId'),
            categoryList: any(named: 'categoryList'),
            moneySourceList: any(named: 'moneySourceList'),
            language: any(named: 'language'),
            currency: any(named: 'currency'),
            pattern: any(named: 'pattern'),
            imagesBase64: null,
            audioBase64: expectedB64,
          )).called(1);
    });

    test('audio + text: both query and audioBase64 forwarded', () async {
      final bytes = Uint8List.fromList([4, 5, 6]);
      // base64([4,5,6]) == 'BAUG'
      const expectedB64 = 'BAUG';

      stubStream('Got it--//--[]');

      final future = chatProvider.sendMessage('note this', audioBytes: bytes);
      await future;

      verify(() => mockChatApiService.streamChat(
            'note this',
            conversationId: any(named: 'conversationId'),
            categoryList: any(named: 'categoryList'),
            moneySourceList: any(named: 'moneySourceList'),
            language: any(named: 'language'),
            currency: any(named: 'currency'),
            pattern: any(named: 'pattern'),
            imagesBase64: null,
            audioBase64: expectedB64,
          )).called(1);
    });

    test('no audio: sendMessage without audioBytes passes null audioBase64', () async {
      stubStream('Hello!--//--[]');

      final future = chatProvider.sendMessage('hello');
      await future;

      verify(() => mockChatApiService.streamChat(
            'hello',
            conversationId: any(named: 'conversationId'),
            categoryList: any(named: 'categoryList'),
            moneySourceList: any(named: 'moneySourceList'),
            language: any(named: 'language'),
            currency: any(named: 'currency'),
            pattern: any(named: 'pattern'),
            imagesBase64: null,
            audioBase64: null,
          )).called(1);
    });

    test('empty bytes guard: sendMessage with Uint8List(0) is a no-op', () async {
      await chatProvider.sendMessage('', audioBytes: Uint8List(0));

      // No messages added, streamChat never called
      expect(chatProvider.messages, isEmpty);
      verifyNever(() => mockChatApiService.streamChat(
            any(),
            conversationId: any(named: 'conversationId'),
            categoryList: any(named: 'categoryList'),
            moneySourceList: any(named: 'moneySourceList'),
            language: any(named: 'language'),
            currency: any(named: 'currency'),
            pattern: any(named: 'pattern'),
            imagesBase64: any(named: 'imagesBase64'),
            audioBase64: any(named: 'audioBase64'),
          ));
    });
  });

  group('FR-5 — voice-error detection (AD-5)', () {
    test('voice error: hadAudio==true + empty records → assistant message replaced with error string', () async {
      final bytes = Uint8List.fromList([7, 8, 9]);
      stubStream("Sorry I didn't understand--//--[]");

      final future = chatProvider.sendMessage('', audioBytes: bytes);
      await future;

      final assistantMsg = chatProvider.messages.lastWhere((m) => m.role == ChatRole.assistant);
      expect(assistantMsg.content, "I didn't catch that. Please try again.");
    });

    test('no audio + empty records: assistant message content kept as-is (normal chat reply)', () async {
      stubStream('Sure!--//--[]');

      final future = chatProvider.sendMessage('how are you');
      await future;

      final assistantMsg = chatProvider.messages.lastWhere((m) => m.role == ChatRole.assistant);
      expect(assistantMsg.content, 'Sure!');
    });

    test('voice + non-empty records: record-card flow runs, no error swap', () async {
      final bytes = Uint8List.fromList([10, 11, 12]);
      final recordJson = jsonEncode([
        {
          'source_id': 1,
          'category_id': 2,
          'amount': 50000,
          'category': 'Food',
          'description': 'Lunch',
          'type': 'expense',
        }
      ]);
      stubStream('Recorded your lunch--//--$recordJson');

      final future = chatProvider.sendMessage('', audioBytes: bytes);
      await future;

      final assistantMsg = chatProvider.messages.lastWhere((m) => m.role == ChatRole.assistant);
      // Content should be the AI text, NOT the voice-error string
      expect(assistantMsg.content, isNot("I didn't catch that. Please try again."));
      expect(assistantMsg.records, isNotNull);
      expect(assistantMsg.records!.length, 1);
    });
  });
}
