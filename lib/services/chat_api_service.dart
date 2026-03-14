import 'dart:convert';
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/services/api_exception.dart';
import 'package:wallet_ai/services/api_service.dart';

class ChatApiService {
  static final ChatApiService _instance = ChatApiService._internal();
  static AppConfig _config = AppConfig();

  factory ChatApiService({AppConfig? config}) {
    if (config != null) _config = config;
    return _instance;
  }

  ChatApiService._internal();

  Stream<String> streamChat(String message) async* {
    try {
      final inputs = {
        'user': '123',
        'query': message,
        'inputs': {'language': 'English'},
      };
      final stream = await ApiService().postStream('/api/chat-flow/wallet-ai-chatbot', data: inputs, token: _config.mainChatApiKey);

      if (stream == null) {
        throw ApiException(message: 'Failed to connect to chat stream.');
      }

      yield* stream.where((data) => data != '[DONE]').map((data) {
        try {
          final decoded = jsonDecode(data);
          return decoded['answer'] as String? ?? '';
        } catch (_) {
          return data;
        }
      });
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }
}
