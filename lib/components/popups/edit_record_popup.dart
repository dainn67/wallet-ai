import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/configs/app_theme.dart';

import 'confirmation_dialog.dart';

/// A popup dialog for editing an existing [Record].
///
/// This dialog allows users to modify the amount, type, money source,
/// category, and description of a record.
class EditRecordPopup extends StatefulWidget {
  final Record record;
  final VoidCallback? onDeleted;

  const EditRecordPopup({super.key, required this.record, this.onDeleted});

  @override
  State<EditRecordPopup> createState() => _EditRecordPopupState();
}

class _EditRecordPopupState extends State<EditRecordPopup> {
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late String _type;
  late int _selectedSourceId;
  late int _selectedCategoryId;
  late DateTime _occurredAt;

  String? _amountError;
  String? _descriptionError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.record.amount.toString());
    _descriptionController = TextEditingController(text: widget.record.description);
    _type = widget.record.type;
    _selectedSourceId = widget.record.moneySourceId;
    _selectedCategoryId = widget.record.categoryId;
    _occurredAt = DateTime.fromMillisecondsSinceEpoch(widget.record.occurredAt);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Consumer<RecordProvider>(
      builder: (context, provider, child) {
        final moneySources = provider.moneySources;
        final categories = provider.categories;

        // Ensure selected values are still valid in the lists
        if (moneySources.isNotEmpty && !moneySources.any((s) => s.sourceId == _selectedSourceId)) {
          _selectedSourceId = moneySources.first.sourceId!;
        }

        final validCategories = categories.where((c) => c.type == _type).toList();
        if (validCategories.isNotEmpty && !validCategories.any((c) => c.categoryId == _selectedCategoryId)) {
          _selectedCategoryId = validCategories.first.categoryId!;
        }

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xxl),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title — locked at top
                Text(
                  l10n.translate('edit_record_title'),
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Scrollable form fields
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Type Toggle
                        _buildLabel(l10n.translate('type_label'), textTheme, colorScheme),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                          ),
                          child: Row(
                            children: [
                              _buildTypeOption(l10n.translate('income_label'), 'income', AppColors.primary, colorScheme),
                              _buildTypeOption(l10n.translate('spent_label'), 'expense', colorScheme.error, colorScheme),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Amount
                        _buildLabel(l10n.translate('income_label'), textTheme, colorScheme),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            errorText: _amountError != null ? l10n.translate(_amountError!) : null,
                          ),
                          onChanged: (_) {
                            if (_amountError != null) {
                              setState(() => _amountError = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Money Source Dropdown
                        _buildLabel(l10n.translate('money_source_label'), textTheme, colorScheme),
                        const SizedBox(height: AppSpacing.sm),
                        _buildDropdown<int>(
                          colorScheme: colorScheme,
                          value: _selectedSourceId,
                          items: moneySources.map((s) => DropdownMenuItem(
                            value: s.sourceId!,
                            child: Text(s.sourceName, style: textTheme.bodyMedium),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSourceId = val);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Category Dropdown
                        _buildLabel(l10n.translate('category_label'), textTheme, colorScheme),
                        const SizedBox(height: AppSpacing.sm),
                        _buildDropdown<int>(
                          colorScheme: colorScheme,
                          value: _selectedCategoryId,
                          items: categories
                              .where((c) => c.type == _type)
                              .map((c) => DropdownMenuItem(
                            value: c.categoryId!,
                            child: Text(
                              provider.getCategoryName(c.categoryId!),
                              style: textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCategoryId = val);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Description
                        _buildLabel(l10n.translate('description_label'), textTheme, colorScheme),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            hintText: l10n.translate('description_hint'),
                            errorText: _descriptionError != null ? l10n.translate(_descriptionError!) : null,
                          ),
                          onChanged: (_) {
                            if (_descriptionError != null) {
                              setState(() => _descriptionError = null);
                            }
                          },
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Event time
                        _buildLabel(l10n.translate('occurred_at_label'), textTheme, colorScheme),
                        const SizedBox(height: AppSpacing.sm),
                        InkWell(
                          onTap: _pickOccurredAt,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(AppRadius.input),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, color: AppColors.onSurfaceVariant, size: 18),
                                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    DateFormat('dd/MM/yyyy  HH:mm').format(_occurredAt),
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down, color: AppColors.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Action Buttons — locked at bottom
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
                        onPressed: () => _handleSave(provider),
                        child: Text(l10n.translate('save_button')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () => _handleDelete(l10n),
                  icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                  label: Text(
                    l10n.translate('delete_button'),
                    style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeOption(String label, String value, Color activeColor, ColorScheme colorScheme) {
    final isSelected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _type = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label, TextTheme textTheme, ColorScheme colorScheme) {
    return Text(
      label,
      style: textTheme.labelLarge?.copyWith(color: AppColors.onSurfaceVariant),
    );
  }

  Widget _buildDropdown<T>({
    required ColorScheme colorScheme,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: AppColors.surface,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }

  void _handleSave(RecordProvider provider) {
    final amountStr = _amountController.text.trim();
    final description = _descriptionController.text.trim();

    double? amount;
    setState(() {
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

      if (description.isEmpty) {
        _descriptionError = 'description_required_error';
      }
    });

    if (_amountError == null && _descriptionError == null && amount != null) {
      final source = provider.moneySources.firstWhere((s) => s.sourceId == _selectedSourceId);

      final updatedRecord = widget.record.copyWith(
        amount: amount,
        description: description,
        type: _type,
        moneySourceId: _selectedSourceId,
        categoryId: _selectedCategoryId,
        sourceName: source.sourceName,
        categoryName: provider.getCategoryName(_selectedCategoryId),
        occurredAt: _occurredAt.millisecondsSinceEpoch,
      );

      Navigator.of(context).pop(updatedRecord);
    }
  }

  Future<void> _pickOccurredAt() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _occurredAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
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
