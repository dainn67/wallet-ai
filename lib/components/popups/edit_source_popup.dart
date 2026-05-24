import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/configs/app_theme.dart';

import 'confirmation_dialog.dart';
import 'transfer_popup.dart';

class EditSourcePopup extends StatefulWidget {
  final MoneySource source;

  const EditSourcePopup({super.key, required this.source});

  @override
  State<EditSourcePopup> createState() => _EditSourcePopupState();
}

class _EditSourcePopupState extends State<EditSourcePopup> {
  late TextEditingController _amountController;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.source.amount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _handleTransfer,
                  icon: Icon(Icons.swap_horiz, color: colorScheme.primary, size: 24),
                  tooltip: l10n.translate('transfer_source_tooltip'),
                ),
                Expanded(
                  child: Text(
                    '${l10n.translate('edit_source_title')} ${widget.source.sourceName}',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
                // NFR-2: test finds Icons.delete_outline — must keep this icon
                IconButton(
                  onPressed: () => _handleDelete(l10n),
                  icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 24),
                  tooltip: l10n.translate('delete_source_tooltip'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              l10n.translate('update_amount_label'),
              style: textTheme.labelLarge?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _amountController,
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                errorText: _amountError != null ? l10n.translate(_amountError!) : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl + AppSpacing.sm),
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
                  child: FilledButton(
                    onPressed: () => _handleSave(l10n),
                    child: Text(l10n.translate('save_button')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSave(LocaleProvider l10n) {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      setState(() => _amountError = 'amount_required_error');
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null) {
      setState(() => _amountError = 'invalid_amount_error');
      return;
    }

    Navigator.of(context).pop(amount);
  }

  void _handleTransfer() {
    // Close this popup and open the TransferPopup with the current source as the origin.
    // Capture the Navigator before pop — `context` is invalid once this State is disposed.
    final navigator = Navigator.of(context);
    final source = widget.source;
    navigator.pop();
    showDialog(
      context: navigator.context,
      builder: (_) => TransferPopup(fromSource: source),
    );
  }

  void _handleDelete(LocaleProvider l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmationDialog(
        title: l10n.translate('delete_source_confirm_title'),
        content: l10n.translate('delete_source_confirm_content'),
        confirmLabel: l10n.translate('delete_button'),
        cancelLabel: l10n.translate('popup_cancel'),
        isDestructive: true,
        onConfirm: () async {
          if (widget.source.sourceId != null) {
            await context.read<RecordProvider>().deleteMoneySource(widget.source.sourceId!);
          }
          if (mounted) {
            Navigator.of(context).pop(); // Close edit popup
          }
        },
      ),
    );
  }
}
