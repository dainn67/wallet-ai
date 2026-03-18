import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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
        await context.read<ChatProvider>().sendMessage(text);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Light blue-grey background
        appBar: AppBar(
          title: Column(
            children: [
              Text('Wallet AI', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              Text(
                'Always active',
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})],
          bottom: TabBar(
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Records'),
              Tab(icon: Icon(Icons.science_outlined), text: 'Test'),
            ],
          ),
        ),
        drawer: _buildAppDrawer(context),
        body: const SafeArea(
          child: TabBarView(
            children: [_ChatTabContent(), _RecordsTabContent(), _TestTabContent()],
          ),
        ),
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Wallet AI',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  Text('Personal finance copilot', style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Chat'),
            onTap: () {
              final controller = DefaultTabController.of(context);
              controller.animateTo(0);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Records'),
            onTap: () {
              final controller = DefaultTabController.of(context);
              controller.animateTo(1);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Test'),
            onTap: () {
              final controller = DefaultTabController.of(context);
              controller.animateTo(2);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final isStreaming = context.watch<ChatProvider>().isStreaming;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(24.0)),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask me anything...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
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
                boxShadow: [
                  if (!isStreaming)
                    BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTabContent extends StatelessWidget {
  const _ChatTabContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context, provider, child) {
              final messages = provider.messages;
              return ListView.builder(
                controller: context.findAncestorStateOfType<_ChatScreenState>()?._scrollController,
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
        context.findAncestorStateOfType<_ChatScreenState>()?._buildInputArea() ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _RecordsTabContent extends StatelessWidget {
  const _RecordsTabContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = provider.filteredRecords;

        final totalIncome = records
            .where((r) => r.type == 'income')
            .fold<double>(0, (sum, r) => sum + r.amount);
        final totalExpense = records
            .where((r) => r.type == 'expense')
            .fold<double>(0, (sum, r) => sum + r.amount);

        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No records yet',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your income and expense records will appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total income',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+${totalIncome.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total spent',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '-${totalExpense.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...records.map((record) {
              final isExpense = record.type == 'expense';
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: (isExpense ? Colors.red : Colors.green).withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(
                        isExpense ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                        color: isExpense ? Colors.red : Colors.green,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.description,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                          ),
                          Text(isExpense ? 'Expense' : 'Income', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Text(
                      '${isExpense ? '-' : '+'}${record.amount.toStringAsFixed(0)} ${record.currency}',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: isExpense ? Colors.red : Colors.green),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _TestTabContent extends StatelessWidget {
  const _TestTabContent();

  static const int _demoSourceId = 1; // Wallet (default from DB)

  Future<void> _addDemoRecords(BuildContext context) async {
    final provider = context.read<RecordProvider>();
    final demoRecords = [
      Record(moneySourceId: _demoSourceId, amount: 3000, currency: 'USD', description: 'Monthly salary', type: 'income'),
      Record(moneySourceId: _demoSourceId, amount: 5.5, currency: 'USD', description: 'Coffee shop', type: 'expense'),
      Record(moneySourceId: _demoSourceId, amount: 85, currency: 'USD', description: 'Groceries', type: 'expense'),
      Record(moneySourceId: _demoSourceId, amount: 500, currency: 'USD', description: 'Freelance project', type: 'income'),
      Record(moneySourceId: _demoSourceId, amount: 12, currency: 'USD', description: 'Lunch', type: 'expense'),
      Record(moneySourceId: _demoSourceId, amount: 200, currency: 'USD', description: 'Bonus', type: 'income'),
    ];
    for (final r in demoRecords) {
      await provider.addRecord(r);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${demoRecords.length} demo records'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _addDemoMoneySources(BuildContext context) async {
    final provider = context.read<RecordProvider>();
    final demoSources = [MoneySource(sourceName: 'Cash'), MoneySource(sourceName: 'Card')];
    for (final s in demoSources) {
      await provider.addMoneySource(s);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${demoSources.length} demo money sources'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Demo data',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        Text(
          'Add sample records and money sources for testing.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _addDemoRecords(context),
          icon: const Icon(Icons.receipt_long),
          label: const Text('Add demo records'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _addDemoMoneySources(context),
          icon: const Icon(Icons.account_balance_wallet),
          label: const Text('Add demo money sources'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

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
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    message.content,
                    style: GoogleFonts.poppins(color: isUser ? Colors.white : const Color(0xFF1E293B), fontSize: 14, height: 1.5),
                  ),
                ),
                if (message.records != null && message.records!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...message.records!.map((record) => _buildRecordCard(context, record)).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, dynamic record) {
    final isExpense = record.type == 'expense';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: (isExpense ? Colors.red : Colors.green).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(
              isExpense ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
              color: isExpense ? Colors.red : Colors.green,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.description,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                ),
                Text(isExpense ? 'Expense' : 'Income', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}${record.amount.toStringAsFixed(0)} ${record.currency}',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: isExpense ? Colors.red : Colors.green),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Text(
            'AI is typing',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey)),
          ),
        ],
      ),
    );
  }
}
