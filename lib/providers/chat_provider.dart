import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/services.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import '../configs/configs.dart';
import 'record_provider.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: 'welcome',
      role: ChatRole.assistant,
      content: 'Hello! I am ${AppConfig().appName}, your personal AI financial assistant. How can I help you today?',
      timestamp: DateTime.now(),
    ),
  ];
  bool _isStreaming = false;
  String? _error;
  String? _conversationId;
  int _dbUpdateVersion = 0;
  StreamSubscription<ChatStreamResponse>? _streamSubscription;
  RecordProvider? _recordProvider;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isStreaming => _isStreaming;
  String? get error => _error;
  String? get conversationId => _conversationId;
  int get dbUpdateVersion => _dbUpdateVersion;

  set recordProvider(RecordProvider? value) {
    _recordProvider = value;
  }

  @visibleForTesting
  void incrementDbUpdateVersionForTest() {
    _dbUpdateVersion++;
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    _error = null;
    final userMessage = ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), role: ChatRole.user, content: content, timestamp: DateTime.now());

    _messages.add(userMessage);
    _isStreaming = true;
    notifyListeners();

    final localAssistantId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
    var currentAssistantId = localAssistantId;
    var assistantMessage = ChatMessage(id: localAssistantId, role: ChatRole.assistant, content: '', timestamp: DateTime.now());
    _messages.add(assistantMessage);
    notifyListeners();

    String fullText = '';
    bool displayTextCompleted = false;

    final categoryList = ChatApiService.formatCategories(_recordProvider?.categories);
    final moneySourceList = ChatApiService.formatMoneySources(_recordProvider?.moneySources);

    final completer = Completer<void>();
    try {
      _streamSubscription?.cancel();
      _streamSubscription = ChatApiService()
          .streamChat(content, conversationId: _conversationId, categoryList: categoryList, moneySourceList: moneySourceList)
          .listen(
            (response) {
              if (response.conversationId != null) {
                _conversationId = response.conversationId;
              }

              final index = _messages.indexWhere((m) => m.id == currentAssistantId);
              if (index != -1) {
                String newId = assistantMessage.id;
                if (response.messageId != null && response.messageId != currentAssistantId) {
                  newId = response.messageId!;
                  currentAssistantId = newId;
                }

                String displayText = assistantMessage.content;

                if (!displayTextCompleted) {
                  if (response.answer.contains(ChatConfig.partialDelimiter) || response.answer.contains(ChatConfig.jsonStart)) {
                    displayText = displayText + response.answer.split(ChatConfig.partialDelimiter).first.split(ChatConfig.jsonStart).first;
                    displayTextCompleted = true;
                  } else {
                    displayText = displayText + response.answer;
                  }
                }

                fullText += response.answer;

                assistantMessage = assistantMessage.copyWith(id: newId, content: displayText);
                _messages[index] = assistantMessage;
                notifyListeners();
              }
            },
            onDone: () async {
              _isStreaming = false;

              final parts = fullText.split(ChatConfig.delimiter);
              if (parts.length >= 2) {
                final jsonString = parts[1].trim();
                try {
                  final List<dynamic> recordsJson = jsonDecode(jsonString);
                  final List<Record> records = [];
                  final recordRepository = RecordRepository();

                  for (var item in recordsJson) {
                    final sourceIdRaw = item['source_id'];
                    final categoryIdRaw = item['category_id'];
                    final amountStr = item['amount']?.toString().trim() ?? '0';
                    final categoryName = item['category']?.toString().trim() ?? '';
                    final description = item['description']?.toString().trim() ?? '';
                    final typeStr = item['type']?.toString().trim().toLowerCase() ?? 'expense';

                    final amount = double.tryParse(amountStr) ?? 0.0;
                    final type = (typeStr == 'income' || typeStr == 'expense') ? typeStr : 'expense';

                    final sourceId = (sourceIdRaw is int) ? sourceIdRaw : (int.tryParse(sourceIdRaw?.toString() ?? '') ?? 1);
                    final categoryId = (categoryIdRaw is int) ? categoryIdRaw : (int.tryParse(categoryIdRaw?.toString() ?? '') ?? 1);

                    final record = Record(
                      moneySourceId: sourceId,
                      categoryId: categoryId,
                      amount: amount,
                      currency: StorageService().getString(StorageService.keyCurrency) ?? 'VND',
                      description: categoryName.isNotEmpty ? '$categoryName: $description' : description,
                      type: type,
                    );

                    // Save to repository
                    await recordRepository.createRecord(record);
                    records.add(record);
                  }

                  if (records.isNotEmpty) {
                    final index = _messages.indexWhere((m) => m.id == currentAssistantId);
                    if (index != -1) {
                      _messages[index] = _messages[index].copyWith(records: records);
                    }
                    _dbUpdateVersion++;
                    await _recordProvider?.loadAll();
                  }
                } catch (e) {
                  debugPrint('Error parsing records JSON: $e');
                }
              }

              notifyListeners();
              completer.complete();
            },
            onError: (error) {
              _isStreaming = false;
              _error = error.toString();
              final index = _messages.indexWhere((m) => m.id == currentAssistantId);
              if (index != -1) {
                _messages[index] = assistantMessage.copyWith(content: '${assistantMessage.content}\nError: $error');
              }
              notifyListeners();
              completer.completeError(error);
            },
            cancelOnError: true,
          );
      return completer.future;
    } catch (e) {
      _isStreaming = false;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
