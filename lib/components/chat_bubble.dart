import 'package:flutter/material.dart';

import 'package:wallet_ai/models/models.dart';

import 'record_widget.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: isUser ? Theme.of(context).colorScheme.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
                  ),
                  child: Text(message.content.trim(), style: TextStyle(color: isUser ? Colors.white : const Color(0xFF1E293B), fontSize: 14, height: 1.5)),
                ),
                if (message.records != null && message.records!.isNotEmpty) ...[const SizedBox(height: 8), ...message.records!.map((record) => RecordWidget(record: record))],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
