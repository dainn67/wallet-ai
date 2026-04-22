import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;

import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/models/models.dart';

import 'api_exception.dart';
import 'api_service.dart';

class ChatApiService {
  static final ChatApiService _instance = ChatApiService._internal();
  static ChatApiService? _mockInstance;

  factory ChatApiService() {
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

    final parents = categories.where((c) => c.parentId == -1).toList();
    final childrenByParent = <int, List<Category>>{};
    for (final c in categories) {
      if (c.parentId != -1) {
        childrenByParent.putIfAbsent(c.parentId, () => []).add(c);
      }
    }

    return parents.map((p) {
      final children = childrenByParent[p.categoryId];
      if (children == null || children.isEmpty) return '${p.categoryId}-${p.name}';
      final childStr = children.map((c) => '${c.categoryId}-${c.name}').join(', ');
      return '${p.categoryId}-${p.name} [subcategories: ${childStr}]';
    }).join('; ');
  }

  Stream<ChatStreamResponse> streamChat(
    String message, {
    String? conversationId,
    String? categoryList,
    String? moneySourceList,
    String language = 'English',
    String currency = 'USD',
    String? pattern,
    List<String>? imagesBase64,
    String? audioBase64,
  }) async* {
    try {
      // ISO-8601 local time without fractional seconds or timezone suffix,
      // e.g. "2026-04-21T22:00:00". Easy for the LLM to template against
      // when producing `occurred_at` (same shape expected back).
      final now = DateTime.now();
      final currentDatetime = now.toIso8601String().split('.').first;

      final Map<String, dynamic> inputs = {
        'user': '123',
        'query': message,
        'inputs': {
          'language': language,
          'currency': currency,
          'current_datetime': currentDatetime,
          if (conversationId != null) 'conversation_id': conversationId,
          if (categoryList != null && categoryList.isNotEmpty) 'category_list': categoryList,
          if (moneySourceList != null && moneySourceList.isNotEmpty) 'money_source_list': moneySourceList,
          if (pattern != null && pattern.isNotEmpty) 'pattern': pattern,
        },
      };
      // AD-2: `images` is a top-level sibling of `query`, not nested inside
      // `inputs` (the Dify variables map). Omitted entirely when empty so the
      // server keeps treating the request as text-only.
      if (imagesBase64 != null && imagesBase64.isNotEmpty) {
        inputs['images'] = imagesBase64;
      }
      // AD-2 (voice): `audio` mirrors the same top-level pattern as `images`.
      // Omitted entirely when absent so the server routes as text/image-only.
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        inputs['audio'] = audioBase64;
      }
      final result = await ApiService().postStream(ApiConfig.chatFlowPath, data: inputs, token: ApiConfig().mainChatApiKey);

      final stream = result.stream;
      if (stream == null) {
        final detail = result.detail ?? 'No response body';
        throw ApiException(
          message: 'Chat stream failed: $detail',
          statusCode: result.statusCode,
        );
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
