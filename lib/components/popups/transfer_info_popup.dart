import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

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
    final formattedDate = DateFormat('dd/MM/yyyy  HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(widget.record.occurredAt));
    final from = widget.record.sourceName ?? '—';
    final to = widget.record.targetSourceName ?? '—';

    return Dialog(
      backgroundColor: Colors.white,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.translate('transfer_title'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                fontFamily: 'PlusJakartaSans',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_horiz, color: Color(0xFF6366F1), size: 28),
              ),
            ),
            const SizedBox(height: 16),
            _row(l10n.translate('transfer_from_label'), from),
            const SizedBox(height: 12),
            _row(l10n.translate('transfer_to_label'), to),
            const SizedBox(height: 12),
            _row(
              l10n.translate('transfer_amount_label'),
              '${widget.record.amount.toStringAsFixed(0)} ${widget.record.currency}',
            ),
            const SizedBox(height: 12),
            _row(l10n.translate('transfer_note_label'), widget.record.description),
            const SizedBox(height: 12),
            _row(l10n.translate('occurred_at_label'), formattedDate),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      l10n.translate('popup_cancel'),
                      style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'PlusJakartaSans'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleDelete(l10n),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(
                      l10n.translate('delete_button'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'PlusJakartaSans'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontFamily: 'PlusJakartaSans'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontFamily: 'PlusJakartaSans'),
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
