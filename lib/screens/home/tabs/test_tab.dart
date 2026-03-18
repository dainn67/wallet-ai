import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

class TestTab extends StatelessWidget {
  const TestTab({super.key});

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
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
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
