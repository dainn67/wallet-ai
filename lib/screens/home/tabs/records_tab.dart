import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/providers/providers.dart';

class RecordsTab extends StatelessWidget {
  const RecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.records.isEmpty && provider.moneySources.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredRecords = provider.filteredRecords;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          children: [
            _buildOverviewCard(context, provider),
            const SizedBox(height: 24),
            if (filteredRecords.isEmpty)
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
              ...filteredRecords.map((record) {
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
                        child: Icon(isExpense ? Icons.arrow_outward_rounded : Icons.call_received_rounded, color: isExpense ? Colors.red : Colors.green, size: 16),
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
                            Text(
                              '${record.categoryName ?? (isExpense ? 'Expense' : 'Income')} • ${record.sourceName ?? 'Unknown'}',
                              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
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
          ],
        );
      },
    );
  }

  Widget _buildOverviewCard(BuildContext context, RecordProvider provider) {
    final records = provider.filteredRecords;
    final totalIncome = records.where((r) => r.type == 'income').fold<double>(0, (sum, r) => sum + r.amount);
    final totalExpense = records.where((r) => r.type == 'expense').fold<double>(0, (sum, r) => sum + r.amount);

    final totalBalance = provider.moneySources.fold<double>(0, (sum, s) => sum + s.amount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalBalance.toStringAsFixed(0),
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildSummaryMiniItem('Income', totalIncome, Colors.greenAccent),
              const SizedBox(width: 40),
              _buildSummaryMiniItem('Spent', totalExpense, Colors.orangeAccent),
            ],
          ),
          if (provider.moneySources.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: Colors.white10),
            ),
            Text('Sources', style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: provider.moneySources.map((source) {
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(source.sourceName, style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                        Text(
                          source.amount.toStringAsFixed(0),
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryMiniItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount.toStringAsFixed(0),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
