import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/chat_message.dart';
import 'package:wallet_ai/providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      context.read<ChatProvider>().sendMessage(text);
      _controller.clear();
      // Scroll to bottom after message is added
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet AI Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) {
                final messages = provider.messages;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('How can I help you today?'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return ChatBubble(message: message);
                  },
                );
              },
            ),
          ),
          if (context.watch<ChatProvider>().isStreaming)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const Divider(height: 1),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: context.watch<ChatProvider>().isStreaming ? null : _handleSend,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.secondaryContainer;
    final textColor = isUser
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16.0).copyWith(
                  bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16.0),
                  bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16.0),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(color: textColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 4.0, right: 4.0),
              child: Text(
                isUser ? 'You' : 'AI',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
