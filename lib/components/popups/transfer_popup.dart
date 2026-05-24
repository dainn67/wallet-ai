import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/configs/app_theme.dart';

/// Records a transfer of money from [fromSource] to another [MoneySource].
///
/// Persists as a single row with `type = 'transfer'`. The repository debits
/// the origin and credits the destination atomically.
class TransferPopup extends StatefulWidget {
  final MoneySource fromSource;

  const TransferPopup({super.key, required this.fromSource});

  @override
  State<TransferPopup> createState() => _TransferPopupState();
}

class _TransferPopupState extends State<TransferPopup> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  int? _toSourceId;
  String? _amountError;
  String? _toError;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    final provider = context.watch<RecordProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final destinations = provider.moneySources
        .where((s) => s.sourceId != null && s.sourceId != widget.fromSource.sourceId)
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.translate('transfer_title'),
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),

            _label(l10n.translate('transfer_from_label'), textTheme),
            const SizedBox(height: AppSpacing.sm),
            _readOnlyField(widget.fromSource.sourceName, textTheme),
            const SizedBox(height: AppSpacing.lg),

            _label(l10n.translate('transfer_to_label'), textTheme),
            const SizedBox(height: AppSpacing.sm),
            if (destinations.isEmpty)
              _readOnlyField(
                l10n.translate('transfer_no_other_source_error'),
                textTheme,
                isError: true,
                colorScheme: colorScheme,
              )
            else
              _buildDestinationDropdown(destinations, textTheme),
            if (_toError != null) ...[
              const SizedBox(height: AppSpacing.xs + AppSpacing.xs),
              Text(
                l10n.translate(_toError!),
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            _label(l10n.translate('transfer_amount_label'), textTheme),
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
            const SizedBox(height: AppSpacing.lg),

            _label(l10n.translate('transfer_note_label'), textTheme),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l10n.translate('description_hint')),
            ),
            const SizedBox(height: AppSpacing.xxl + AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: Text(l10n.translate('popup_cancel')),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: (_saving || destinations.isEmpty) ? null : () => _handleSave(provider, l10n),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                          )
                        : Text(l10n.translate('transfer_button')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, TextTheme textTheme) => Text(
        text,
        style: textTheme.labelLarge?.copyWith(color: AppColors.onSurfaceVariant),
      );

  Widget _readOnlyField(String text, TextTheme textTheme, {bool isError = false, ColorScheme? colorScheme}) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: AppColors.outline),
        ),
        child: Text(
          text,
          style: textTheme.bodyMedium?.copyWith(
            color: isError ? (colorScheme?.error ?? AppColors.error) : AppColors.onSurface,
          ),
        ),
      );

  Widget _buildDestinationDropdown(List<MoneySource> destinations, TextTheme textTheme) {
    // Reset selection if it no longer exists in the list.
    if (_toSourceId != null && !destinations.any((s) => s.sourceId == _toSourceId)) {
      _toSourceId = null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _toSourceId,
          isExpanded: true,
          hint: Text(
            context.read<LocaleProvider>().translate('transfer_select_to_hint'),
            style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          dropdownColor: AppColors.surface,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.onSurfaceVariant),
          items: destinations
              .map(
                (s) => DropdownMenuItem<int>(
                  value: s.sourceId!,
                  child: Text(s.sourceName, style: textTheme.bodyMedium),
                ),
              )
              .toList(),
          onChanged: (val) {
            setState(() {
              _toSourceId = val;
              if (_toError != null) _toError = null;
            });
          },
        ),
      ),
    );
  }

  Future<void> _handleSave(RecordProvider provider, LocaleProvider l10n) async {
    final amountStr = _amountController.text.trim();
    final description = _descriptionController.text.trim();

    double? amount;
    setState(() {
      _amountError = null;
      _toError = null;
      if (amountStr.isEmpty) {
        _amountError = 'amount_required_error';
      } else {
        amount = double.tryParse(amountStr);
        if (amount == null) {
          _amountError = 'invalid_amount_error';
        } else if (amount! <= 0) {
          _amountError = 'amount_positive_error';
        }
      }
      if (_toSourceId == null) {
        _toError = 'transfer_select_destination_error';
      }
    });

    if (_amountError != null || _toError != null || amount == null) return;

    setState(() => _saving = true);
    try {
      await provider.createTransfer(
        fromSourceId: widget.fromSource.sourceId!,
        toSourceId: _toSourceId!,
        amount: amount!,
        description: description.isEmpty ? l10n.translate('transfer_default_description') : description,
        occurredAt: DateTime.now(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
