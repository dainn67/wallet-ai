import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/components/components.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

class RecordsTab extends StatelessWidget {
  const RecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    return Consumer<RecordProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.records.isEmpty && provider.moneySources.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = provider.filteredRecords;
        final totalIncome = provider.filteredTotalIncome;
        final totalExpense = provider.filteredTotalExpense;
        final totalBalance = provider.totalBalance;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RecordsOverview(
                totalBalance: totalBalance,
                totalIncome: totalIncome,
                totalExpense: totalExpense,
                sources: provider.moneySources,
                onSourceTap: (source) => _showEditSourceDialog(context, source),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                children: [
                  if (records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            l10n.translate('no_records'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.translate('no_records_subtitle'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        l10n.translate('recent_records'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ),
                    ..._buildGroupedRecords(context, records, l10n),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildGroupedRecords(BuildContext context, List<Record> records, LocaleProvider l10n) {
    if (records.isEmpty) return [];

    final List<Widget> groupedWidgets = [];
    String? lastDateLabel;

    for (final record in records) {
      final date = DateTime.fromMillisecondsSinceEpoch(record.occurredAt);
      final dateLabel = _formatDateLabel(context, date, l10n);

      if (lastDateLabel != dateLabel) {
        lastDateLabel = dateLabel;
        groupedWidgets.add(DateDivider(label: lastDateLabel));
      }

      groupedWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RecordWidget(record: record, isEditable: true, onEdit: () => _showEditRecordPopup(context, record)),
        ),
      );
    }

    return groupedWidgets;
  }

  String _formatDateLabel(BuildContext context, DateTime date, LocaleProvider l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final recordDate = DateTime(date.year, date.month, date.day);

    if (recordDate == today) {
      return l10n.translate('today_label');
    } else if (recordDate == yesterday) {
      return l10n.translate('yesterday_label');
    } else {
      if (l10n.language == AppLanguage.english) {
        return DateFormat('EEE, d MMM yyyy').format(date);
      } else {
        return DateFormat('EEEE, d/M/yyyy').format(date);
      }
    }
  }

  void _showEditRecordPopup(BuildContext context, Record record) async {
    final updatedRecord = await showDialog<Record>(
      context: context,
      builder: (context) => EditRecordPopup(record: record),
    );

    if (updatedRecord != null && context.mounted) {
      await context.read<RecordProvider>().updateRecord(updatedRecord);
    }
  }

  void _showEditSourceDialog(BuildContext context, MoneySource source) async {
    final newAmount = await showDialog<double>(
      context: context,
      builder: (context) => EditSourcePopup(source: source),
    );

    if (newAmount != null && context.mounted) {
      await context.read<RecordProvider>().updateMoneySource(source.copyWith(amount: newAmount));
    }
  }
}
