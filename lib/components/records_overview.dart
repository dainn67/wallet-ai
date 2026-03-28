import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/helpers/currency_helper.dart';
import 'package:wallet_ai/models/models.dart';
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

  const RecordsOverview({super.key, required this.totalBalance, required this.totalIncome, required this.totalExpense, required this.sources, this.onSourceTap, this.onAddSource});

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total Balance Section
          _buildBalanceHeader(l10n),
          const SizedBox(height: 12),

          // Income and Expense Summary
          Row(
            children: [
              Expanded(child: _buildSummaryItem(l10n.translate('income_label'), totalIncome, Colors.greenAccent)),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryItem(l10n.translate('spent_label'), totalExpense, Colors.orangeAccent)),
            ],
          ),

          // Sources Section (Horizontal List)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Divider(color: Colors.white10, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.translate('sources_label'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500),
              ),
              IconButton(
                onPressed:
                    onAddSource ??
                    () async {
                      final result = await showDialog<MoneySource>(context: context, builder: (context) => const AddSourcePopup());
                      if (result != null && context.mounted) {
                        await context.read<RecordProvider>().addMoneySource(result);
                      }
                    },
                icon: const Icon(Icons.add_rounded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
          if (sources.isNotEmpty)
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
      ),
    );
  }

  Widget _buildBalanceHeader(LocaleProvider l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('total_balance_label'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Total balance
                  Text(
                    CurrencyHelper.format(totalBalance),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      L10nConfig.currencyCodes[l10n.currency] ?? 'VND',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
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
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyHelper.format(amount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  Text(source.sourceName, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                  Text(
                    CurrencyHelper.format(source.amount),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Positioned(top: 0, right: 0, child: Icon(Icons.edit_rounded, size: 10, color: Colors.white.withValues(alpha: 0.3))),
            ],
          ),
        ),
      ),
    );
  }
}
