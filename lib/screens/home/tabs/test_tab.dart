import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/services/services.dart';

class TestTab extends StatefulWidget {
  const TestTab({super.key});

  @override
  State<TestTab> createState() => _TestTabState();
}

class _TestTabState extends State<TestTab> {
  static const int _demoSourceId = 1; // Wallet (default from DB)
  String? _apiResult;
  bool _isLoading = false;
  String? _storedPattern;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  void _loadStoredData() {
    setState(() {
      _storedPattern = StorageService().getString(StorageService.keyUserPattern);
      final lastUpdateMs = StorageService().getInt(StorageService.keyLastPatternUpdateTime);
      if (lastUpdateMs != null && lastUpdateMs != -1) {
        _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdateMs);
      } else {
        _lastUpdateTime = null;
      }
    });
  }

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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added 6 demo records'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _addDemoMoneySources(BuildContext context) async {
    final provider = context.read<RecordProvider>();
    final demoSources = [MoneySource(sourceName: 'Cash'), MoneySource(sourceName: 'Card')];
    for (final s in demoSources) {
      await provider.addMoneySource(s);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added 2 demo money sources'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _testAiSync() async {
    setState(() {
      _isLoading = true;
      _apiResult = null;
    });

    try {
      await AiPatternService().updateUserPattern(force: true);
      final result = StorageService().getString(StorageService.keyUserPattern);
      setState(() {
        _apiResult = result ?? 'Sync completed but no pattern returned.';
      });
    } catch (e) {
      setState(() {
        _apiResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _loadStoredData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Demo data',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        const Text('Add sample records and money sources for testing.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _addDemoRecords(context),
          icon: const Icon(Icons.receipt_long),
          label: const Text('Add demo records'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _addDemoMoneySources(context),
          icon: const Icon(Icons.account_balance_wallet),
          label: const Text('Add demo money sources'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'AI Pattern Sync',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        const Text('Test syncing your records with the server.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _isLoading ? null : _testAiSync,
          icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.sync),
          label: Text(_isLoading ? 'Syncing...' : 'Test AI Sync'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (_apiResult != null) ...[
          const SizedBox(height: 24),
          const Text(
            'Result:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              _apiResult!,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _apiResult = null;
              });
            },
            icon: const Icon(Icons.clear, size: 18),
          label: const Text('Clear result'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
        ),
      ],
      const SizedBox(height: 32),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Stored AI Pattern',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          IconButton(onPressed: _loadStoredData, icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF6366F1))),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        _lastUpdateTime != null ? 'Last updated: ${DateFormat('HH:mm d MMM yyyy').format(_lastUpdateTime!)}' : 'Never updated',
        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      ),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: SingleChildScrollView(
          child: Text(
            _storedPattern?.isNotEmpty == true ? _storedPattern! : 'No pattern stored yet.',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF334155), height: 1.4),
          ),
        ),
      ),
      const SizedBox(height: 32),
    ],
    );
  }
}
