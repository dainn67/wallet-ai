import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/helpers/currency_helper.dart';

/// A reusable component for displaying a [Record] (income or expense).
///
/// This is a "dumb" component that only displays the data passed to it.
class RecordWidget extends StatelessWidget {
  final Record record;
  final VoidCallback? onTap;

  const RecordWidget({super.key, required this.record, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isExpense = record.type == 'expense';

    // Use established colors for income/expense
    final recordColor = isExpense ? Colors.red : Colors.green;
    final backgroundColor = recordColor.withValues(alpha: 0.1);
    final formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(record.lastUpdated));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
              child: Icon(isExpense ? Icons.arrow_outward_rounded : Icons.call_received_rounded, color: recordColor, size: 16),
            ),
            const SizedBox(width: 12),

            // Description and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 2),
                  Text(_buildSubtitle(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),

            // Amount and Date
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? '-' : '+'}${CurrencyHelper.format(record.amount)} ${record.currency}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: recordColor),
                ),
                const SizedBox(height: 2),
                Text(formattedDate, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final isExpense = record.type == 'expense';
    final parts = <String>[];

    // Add category if available
    if (record.categoryName != null && record.categoryName!.isNotEmpty) {
      parts.add(record.categoryName!);
    } else {
      parts.add(isExpense ? 'Expense' : 'Income');
    }

    // Add source if available
    if (record.sourceName != null && record.sourceName!.isNotEmpty) {
      parts.add(record.sourceName!);
    }

    return parts.join(' • ');
  }
}
