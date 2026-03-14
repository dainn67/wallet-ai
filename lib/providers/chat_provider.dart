import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wallet_ai/models/chat_message.dart';
import 'package:wallet_ai/models/chat_stream_response.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/services/chat_api_service.dart';
import 'package:wallet_ai/services/database_service.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [ChatMessage(id: 'welcome', role: ChatRole.assistant, content: 'Hello! How can I help you today?', timestamp: DateTime.now())];
  bool _isStreaming = false;
  String? _error;
  String? _conversationId;
  StreamSubscription<ChatStreamResponse>? _streamSubscription;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isStreaming => _isStreaming;
  String? get error => _error;
  String? get conversationId => _conversationId;

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

    try {
      _streamSubscription?.cancel();
      _streamSubscription = ChatApiService()
          .streamChat(content, conversationId: _conversationId)
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
                final partialDelimiter = '--'; // Partial delimiter of --//--

                if (!displayTextCompleted) {
                  if (response.answer.contains(partialDelimiter)) {
                    displayText = displayText + response.answer.split(partialDelimiter).first;
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
              print('onDone: full: $fullText');
              _isStreaming = false;

              final parts = fullText.split('--//--');
              // Format: text --//-- source --//-- amount --//-- category --//-- description --//-- type
              if (parts.length >= 6) {
                final sourceName = parts[1].trim();
                final amountStr = parts[2].trim();
                final category = parts[3].trim();
                final description = parts[4].trim();
                final typeStr = parts[5].trim().toLowerCase();

                final amount = double.tryParse(amountStr) ?? 0.0;
                final type = (typeStr == 'income' || typeStr == 'expense') ? typeStr : 'expense';

                // Find money source ID
                final dbService = DatabaseService();
                final source = await dbService.getMoneySourceByName(sourceName);
                final sourceId = source?.sourceId ?? 1; // Default to 1 (Wallet) if not found

                final record = Record(
                  moneySourceId: sourceId,
                  amount: amount,
                  currency: 'VND', // Default to VND as per Vietnam context (100k)
                  description: '$category: $description',
                  type: type,
                );

                final index = _messages.indexWhere((m) => m.id == currentAssistantId);
                if (index != -1) {
                  _messages[index] = _messages[index].copyWith(records: [record]);
                }
              }

              notifyListeners();
            },
            onError: (error) {
              _isStreaming = false;
              _error = error.toString();
              final index = _messages.indexWhere((m) => m.id == currentAssistantId);
              if (index != -1) {
                _messages[index] = assistantMessage.copyWith(content: '${assistantMessage.content}\nError: $error');
              }
              notifyListeners();
            },
            cancelOnError: true,
          );
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
