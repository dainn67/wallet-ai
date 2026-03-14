import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wallet_ai/models/chat_message.dart';
import 'package:wallet_ai/services/chat_api_service.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isStreaming = false;
  String? _error;
  StreamSubscription<String>? _streamSubscription;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isStreaming => _isStreaming;
  String? get error => _error;

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    _error = null;
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: content,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isStreaming = true;
    notifyListeners();

    // Placeholder assistant message
    final assistantMessageId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
    var assistantMessage = ChatMessage(
      id: assistantMessageId,
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
    );
    _messages.add(assistantMessage);
    notifyListeners();

    try {
      _streamSubscription?.cancel();
      _streamSubscription = ChatApiService().streamChat(content).listen(
        (chunk) {
          final index = _messages.indexWhere((m) => m.id == assistantMessageId);
          if (index != -1) {
            assistantMessage = assistantMessage.copyWith(
              content: '${assistantMessage.content}$chunk',
            );
            _messages[index] = assistantMessage;
            notifyListeners();
          }
        },
        onDone: () {
          _isStreaming = false;
          notifyListeners();
        },
        onError: (error) {
          _isStreaming = false;
          _error = error.toString();
          // You might want to update the message to indicate error
          final index = _messages.indexWhere((m) => m.id == assistantMessageId);
          if (index != -1) {
             _messages[index] = assistantMessage.copyWith(
               content: '${assistantMessage.content}\nError: $error',
             );
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
