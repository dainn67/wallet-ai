import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/components/components.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/models/models.dart';

class RecordsTab extends StatelessWidget {
  const RecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.records.isEmpty && provider.moneySources.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = provider.filteredRecords;
        final totalIncome = records.where((r) => r.type == 'income').fold<double>(0, (sum, r) => sum + r.amount);
        final totalExpense = records.where((r) => r.type == 'expense').fold<double>(0, (sum, r) => sum + r.amount);
        final totalBalance = provider.moneySources.fold<double>(0, (sum, s) => sum + s.amount);

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          children: [
            RecordsOverview(
              totalBalance: totalBalance,
              totalIncome: totalIncome,
              totalExpense: totalExpense,
              sources: provider.moneySources,
              onSourceTap: (source) => _showEditSourceDialog(context, source),
            ),
            const SizedBox(height: 24),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
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
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Recent Records',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                ),
              ),
              ...records.map((record) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RecordWidget(record: record),
                  )),
            ],
          ],
        );
      },
    );
  }

  void _showEditSourceDialog(BuildContext context, MoneySource source) {
    final controller = TextEditingController(text: source.amount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${source.sourceName}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'New Amount',
            hintText: 'Enter total amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newAmount = double.tryParse(controller.text);
              if (newAmount != null) {
                context.read<RecordProvider>().updateMoneySource(
                      source.copyWith(amount: newAmount),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
