class ChatStreamResponse {
  final String answer;
  final String? conversationId;
  final String? messageId;
  final String event;

  ChatStreamResponse({
    required this.answer,
    this.conversationId,
    this.messageId,
    this.event = 'message',
  });

  factory ChatStreamResponse.fromJson(Map<String, dynamic> json) {
    return ChatStreamResponse(
      answer: json['answer'] as String? ?? '',
      conversationId: json['conversation_id'] as String?,
      messageId: json['message_id'] as String?,
      event: json['event'] as String? ?? 'message',
    );
  }

  @override
  String toString() {
    return 'ChatStreamResponse(answer: $answer, conversationId: $conversationId, messageId: $messageId, event: $event)';
  }
}
