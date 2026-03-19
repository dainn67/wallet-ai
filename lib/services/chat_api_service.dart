import 'dart:convert';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/models/models.dart';
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

  static String formatMoneySources(List<MoneySource> sources) {
    if (sources.isEmpty) return 'No money sources available';
    return sources.map((s) => '${s.sourceId}-${s.sourceName}').join(', ');
  }

  static String formatCategories(List<Category> categories) {
    if (categories.isEmpty) return 'No categories available';
    return categories.map((c) => '${c.categoryId}-${c.name}').join(', ');
  }

  Stream<ChatStreamResponse> streamChat(String message, {String? conversationId}) async* {
    try {
      final inputs = {
        'user': '123',
        'query': message,
        'inputs': {'language': 'English', if (conversationId != null) 'conversation_id': conversationId},
      };
      final stream = await ApiService().postStream('/api/chat-flow/wallet-ai-chatbot', data: inputs, token: _config.mainChatApiKey);

      if (stream == null) {
        throw ApiException(message: 'Failed to connect to chat stream.');
      }

      yield* stream.map((data) {
        try {
          final decoded = jsonDecode(data);
          return ChatStreamResponse.fromJson(decoded);
        } catch (_) {
          return ChatStreamResponse(answer: data, event: 'error');
        }
      });
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }
}
