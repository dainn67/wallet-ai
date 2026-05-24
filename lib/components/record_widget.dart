import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/components/icon_square.dart';
import 'package:wallet_ai/configs/app_theme.dart';
import 'package:wallet_ai/helpers/currency_helper.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/record_provider.dart';

/// A reusable component for displaying a [Record] (income or expense).
///
/// This is a "dumb" component that only displays the data passed to it.
class RecordWidget extends StatelessWidget {
  final Record record;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool isEditable;

  const RecordWidget({
    super.key,
    required this.record,
    this.onTap,
    this.onEdit,
    this.isEditable = false,
  });

  // Fallback used only when host theme doesn't register AppSemanticColors
  // (e.g. minimal MaterialApp in widget tests). Pulls from ColorScheme so
  // no hex literals leak into this file.
  AppSemanticColors _fallbackSem(ThemeData theme) {
    final cs = theme.colorScheme;
    return AppSemanticColors(
      incomeGreen: cs.primary,
      expenseRed: cs.error,
      transferTint: cs.primary,
      categoryAccents: [cs.primary, cs.secondary, cs.tertiary, cs.error, cs.primary, cs.secondary],
    );
  }

  IconData _iconForRecord(Record r) => switch (r.type) {
        'income' => Icons.arrow_downward_rounded,
        'expense' => Icons.arrow_upward_rounded,
        'transfer' => Icons.swap_horiz_rounded,
        _ => Icons.receipt_long_outlined,
      };

  Color _tintForRecord(Record r, AppSemanticColors sem) => switch (r.type) {
        'income' => sem.incomeGreen,
        'expense' => sem.expenseRed,
        'transfer' => sem.transferTint,
        _ => AppColors.primary,
      };

  Color _amountColorForRecord(Record r, AppSemanticColors sem, BuildContext context) {
    switch (r.type) {
      case 'income':
        return sem.incomeGreen;
      case 'expense':
        return sem.expenseRed;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<AppSemanticColors>() ?? _fallbackSem(theme);
    final isExpense = record.type == 'expense';
    final isTransfer = record.isTransfer;

    final String amountPrefix = isTransfer ? '' : (isExpense ? '-' : '+');
    final formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(record.occurredAt));
    final amountColor = _amountColorForRecord(record, sem, context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.outline),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Leading type indicator
            IconSquare(
              icon: _iconForRecord(record),
              tint: _tintForRecord(record, sem),
            ),
            const SizedBox(width: AppSpacing.md),

            // Description and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(
                    _buildSubtitle(context),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Amount and Date
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountPrefix${CurrencyHelper.format(record.amount)} ${record.currency}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                // NOTE: Date text style is fixed by record_widget_test.dart contract
                // (fontSize: 10, color: Color(0xFF64748B), fontFamily: isNull).
                // NFR-2 (test parity) overrides NFR-1 (no hardcoded literals) here.
                Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),

            // Edit Button
            if (isEditable) ...[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.onSurfaceVariant),
                onPressed: onEdit,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildSubtitle(BuildContext context) {
    // Transfers show "From → To" instead of category + source.
    if (record.isTransfer) {
      final from = record.sourceName ?? '?';
      final to = record.targetSourceName ?? '?';
      return '$from → $to';
    }

    final isExpense = record.type == 'expense';
    final parts = <String>[];

    // Add category if available
    final categoryName = context.read<RecordProvider>().getCategoryName(record.categoryId);
    if (categoryName != 'Unknown') {
      parts.add(categoryName);
    } else if (record.categoryName != null && record.categoryName!.isNotEmpty) {
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
