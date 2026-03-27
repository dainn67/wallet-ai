import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/api_exception.dart';
import 'package:wallet_ai/services/api_service.dart';

class ChatApiService {
  static final ChatApiService _instance = ChatApiService._internal();
  static ChatApiService? _mockInstance;
  static AppConfig _config = AppConfig();

  factory ChatApiService({AppConfig? config}) {
    if (config != null) _config = config;
    return _mockInstance ?? _instance;
  }

  ChatApiService._internal();

  @visibleForTesting
  static void setMockInstance(ChatApiService? instance) {
    _mockInstance = instance;
  }

  static String formatMoneySources(List<MoneySource>? sources) {
    if (sources == null || sources.isEmpty) return 'No money sources available';
    return sources.map((s) => '${s.sourceId}-${s.sourceName}').join(', ');
  }

  static String formatCategories(List<Category>? categories) {
    if (categories == null || categories.isEmpty) return 'No categories available';
    final categoryMap = {for (var c in categories) c.categoryId: c.name};
    return categories.map((c) {
      if (c.parentId != -1) {
        final parentName = categoryMap[c.parentId] ?? 'Unknown';
        return '${c.categoryId}-${c.name} (Parent: $parentName)';
      }
      return '${c.categoryId}-${c.name}';
    }).join(', ');
  }

  Stream<ChatStreamResponse> streamChat(String message, {String? conversationId, String? categoryList, String? moneySourceList, String language = 'English', String currency = 'USD'}) async* {
    try {
      final inputs = {
        'user': '123',
        'query': message,
        'inputs': {
          'language': language,
          'currency': currency,
          if (conversationId != null) 'conversation_id': conversationId,
          if (categoryList != null && categoryList.isNotEmpty) 'category_list': categoryList,
          if (moneySourceList != null && moneySourceList.isNotEmpty) 'money_source_list': moneySourceList,
        },
      };
      final stream = await ApiService().postStream('/api/chat-flow/wallet-ai-chatbot', data: inputs, token: _config.mainChatApiKey);

      if (stream == null) {
        throw ApiException(message: 'Error: stream in streamChat = null');
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
