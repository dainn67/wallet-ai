import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/configs/app_theme.dart';

/// A popup dialog for adding a new [MoneySource].
///
/// This dialog captures the source name and an initial balance.
class AddSourcePopup extends StatefulWidget {
  const AddSourcePopup({super.key});

  @override
  State<AddSourcePopup> createState() => _AddSourcePopupState();
}

class _AddSourcePopupState extends State<AddSourcePopup> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _nameError;
  String? _amountError;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.translate('add_source_title'),
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildLabel(l10n.translate('source_name_label'), textTheme),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nameController,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                hintText: l10n.translate('source_name_hint'),
                errorText: _nameError != null ? l10n.translate(_nameError!) : null,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildLabel(l10n.translate('initial_amount_label'), textTheme),
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

  Widget _buildLabel(String label, TextTheme textTheme) {
    return Text(
      label,
      style: textTheme.labelLarge?.copyWith(color: AppColors.onSurfaceVariant),
    );
  }

  void _handleSave(LocaleProvider l10n) {
    final name = _nameController.text.trim();
    final amountStr = _amountController.text.trim();

    setState(() {
      if (name.isEmpty) {
        _nameError = 'name_required_error';
      } else {
        _nameError = null;
      }

      if (amountStr.isEmpty) {
        _amountError = 'amount_required_error';
      } else {
        final amount = double.tryParse(amountStr);
        if (amount == null) {
          _amountError = 'invalid_amount_error';
        } else if (amount < 0) {
          _amountError = 'amount_positive_error';
        } else {
          _amountError = null;
        }
      }
    });

    if (_nameError == null && _amountError == null) {
      final amount = double.parse(amountStr);
      Navigator.of(context).pop(MoneySource(sourceName: name, amount: amount));
    }
  }
}
