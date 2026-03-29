import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/services.dart';

import 'locale_provider.dart';
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
  LocaleProvider? _localeProvider;

  ChatProvider({RecordProvider? recordProvider, LocaleProvider? localeProvider}) : _recordProvider = recordProvider, _localeProvider = localeProvider;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isStreaming => _isStreaming;
  String? get error => _error;
  String? get conversationId => _conversationId;
  int get dbUpdateVersion => _dbUpdateVersion;

  set recordProvider(RecordProvider? value) {
    _recordProvider = value;
  }

  set localeProvider(LocaleProvider? value) {
    _localeProvider = value;
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
    var assistantMessage = ChatMessage(
      id: localAssistantId,
      role: ChatRole.assistant,
      content: _localeProvider?.translate('chat_analyzing') ?? 'Analyzing...',
      timestamp: DateTime.now(),
    );
    _messages.add(assistantMessage);
    notifyListeners();

    String fullText = '';
    bool displayTextCompleted = false;
    bool hasStartedStreaming = false;

    final categoryList = ChatApiService.formatCategories(_recordProvider?.categories);
    final moneySourceList = ChatApiService.formatMoneySources(_recordProvider?.moneySources);
    final language = _localeProvider?.language == AppLanguage.vietnamese ? 'Vietnamese' : 'English';
    final currency = L10nConfig.currencyCodes[_localeProvider?.currency] ?? 'USD';

    final completer = Completer<void>();
    try {
      _streamSubscription?.cancel();
      _streamSubscription = ChatApiService()
          .streamChat(content, conversationId: _conversationId, categoryList: categoryList, moneySourceList: moneySourceList, language: language, currency: currency)
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

                if (!hasStartedStreaming && response.answer.isNotEmpty) {
                  displayText = '';
                  hasStartedStreaming = true;
                }

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
                print('jsonString: $jsonString');
                try {
                  final List<dynamic> recordsJson = jsonDecode(jsonString);
                  final List<Record> records = [];

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

                    final currencyString = L10nConfig.currencyCodes[_localeProvider?.currency] ?? 'USD';
                    final record = Record(
                      moneySourceId: sourceId,
                      categoryId: categoryId,
                      amount: amount,
                      currency: currencyString,
                      description: categoryName.isNotEmpty ? '$categoryName: $description' : description,
                      type: type,
                    );

                    // Save via RecordProvider (AD-1: provider-only repository access)
                    final recordId = await _recordProvider!.createRecord(record);
                    records.add(record.copyWith(recordId: recordId));
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

  void updateMessageRecord(String messageId, Record updatedRecord) {
    final msgIndex = _messages.indexWhere((m) => m.id == messageId);
    if (msgIndex != -1) {
      final records = _messages[msgIndex].records;
      if (records != null) {
        final recordIndex = records.indexWhere((r) => r.recordId == updatedRecord.recordId);
        if (recordIndex != -1) {
          final newRecords = List<Record>.from(records);
          newRecords[recordIndex] = updatedRecord;
          _messages[msgIndex] = _messages[msgIndex].copyWith(records: newRecords);
          notifyListeners();
        }
      }
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
