import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/helpers/currency_helper.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'popups/add_source_popup.dart';

/// A component that displays a financial overview including total balance,
/// income, expenses, and a horizontal list of money sources.
class RecordsOverview extends StatelessWidget {
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;
  final List<MoneySource> sources;
  final Function(MoneySource)? onSourceTap;
  final VoidCallback? onAddSource;

  const RecordsOverview({
    super.key,
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.sources,
    this.onSourceTap,
    this.onAddSource,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Balance Section
          _buildBalanceHeader(),
          const SizedBox(height: 24),

          // Income and Expense Summary
          Row(
            children: [
              _buildSummaryItem('Income', totalIncome, Colors.greenAccent),
              const SizedBox(width: 40),
              _buildSummaryItem('Spent', totalExpense, Colors.orangeAccent),
            ],
          ),

          // Sources Section (Horizontal List)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Colors.white10, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sources',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                onPressed: onAddSource ??
                    () async {
                      final result = await showDialog<MoneySource>(
                        context: context,
                        builder: (context) => const AddSourcePopup(),
                      );
                      if (result != null && context.mounted) {
                        await context.read<RecordProvider>().addMoneySource(result);
                      }
                    },
                icon: const Icon(Icons.add_rounded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 18,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sources.length,
                itemBuilder: (context, index) {
                  final source = sources[index];
                  return _buildSourceCard(source);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Balance',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyHelper.format(totalBalance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
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
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyHelper.format(amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceCard(MoneySource source) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      constraints: const BoxConstraints(minWidth: 100),
      child: InkWell(
        onTap: () => onSourceTap?.call(source),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.sourceName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    CurrencyHelper.format(source.amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.edit_rounded,
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
