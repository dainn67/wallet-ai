import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/configs/app_theme.dart';

import 'confirmation_dialog.dart';

/// Read-only summary of an existing transfer [Record].
///
/// Transfers are not editable in v1 — this popup exposes only a Delete action.
/// To change a transfer the user deletes it and creates a new one.
class TransferInfoPopup extends StatefulWidget {
  final Record record;
  final VoidCallback? onDeleted;

  const TransferInfoPopup({super.key, required this.record, this.onDeleted});

  @override
  State<TransferInfoPopup> createState() => _TransferInfoPopupState();
}

class _TransferInfoPopupState extends State<TransferInfoPopup> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final formattedDate = DateFormat('dd/MM/yyyy  HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(widget.record.occurredAt));
    final from = widget.record.sourceName ?? '—';
    final to = widget.record.targetSourceName ?? '—';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.translate('transfer_title'),
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg - AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.swap_horiz, color: AppColors.primary, size: 28),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _row(l10n.translate('transfer_from_label'), from, textTheme),
            const SizedBox(height: AppSpacing.md),
            _row(l10n.translate('transfer_to_label'), to, textTheme),
            const SizedBox(height: AppSpacing.md),
            _row(
              l10n.translate('transfer_amount_label'),
              '${widget.record.amount.toStringAsFixed(0)} ${widget.record.currency}',
              textTheme,
            ),
            const SizedBox(height: AppSpacing.md),
            _row(l10n.translate('transfer_note_label'), widget.record.description, textTheme),
            const SizedBox(height: AppSpacing.md),
            _row(l10n.translate('occurred_at_label'), formattedDate, textTheme),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.translate('popup_cancel')),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _handleDelete(l10n),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l10n.translate('delete_button')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, TextTheme textTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            textAlign: TextAlign.end,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _handleDelete(LocaleProvider l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmationDialog(
        title: l10n.translate('delete_record_confirm_title'),
        content: l10n.translate('delete_record_confirm_content'),
        confirmLabel: l10n.translate('delete_button'),
        cancelLabel: l10n.translate('popup_cancel'),
        isDestructive: true,
        onConfirm: () async {
          await context.read<RecordProvider>().deleteRecord(widget.record.recordId);
          widget.onDeleted?.call();
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
