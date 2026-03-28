import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/components/components.dart';
import 'package:wallet_ai/providers/providers.dart';

class ChatTab extends StatefulWidget {
  final FocusNode? focusNode;
  const ChatTab({super.key, this.focusNode});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    _chatProvider.addListener(_onChatProviderUpdate);
  }

  @override
  void dispose() {
    _chatProvider.removeListener(_onChatProviderUpdate);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatProviderUpdate() {
    if (!mounted) return;
    final provider = context.read<ChatProvider>();
    if (provider.isStreaming) {
      _scrollToBottomIfNearBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _scrollToBottomIfNearBottom() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final isNearBottom = position.pixels >= position.maxScrollExtent - 100;
      if (isNearBottom) {
        _scrollToBottom();
      }
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _controller.clear();
      try {
        FocusManager.instance.primaryFocus?.unfocus();
        await context.read<ChatProvider>().sendMessage(text);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context, provider, child) {
              final messages = provider.messages;
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return ChatBubble(message: message);
                },
              );
            },
          ),
        ),
        if (context.watch<ChatProvider>().isStreaming) const _StreamingIndicator(),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildInputArea() {
    final isStreaming = context.watch<ChatProvider>().isStreaming;
    final l10n = context.watch<LocaleProvider>();
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(24.0)),
              child: TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.translate('chat_hint'),
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => isStreaming ? null : _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: isStreaming ? null : _handleSend,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isStreaming ? Colors.grey : Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [if (!isStreaming) BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamingIndicator extends StatelessWidget {
  const _StreamingIndicator();

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Text(
            l10n.translate('ai_typing'),
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey))),
        ],
      ),
    );
  }
}
