import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

/// A popup dialog for editing an existing [Record].
///
/// This dialog allows users to modify the amount, type, money source,
/// category, and description of a record.
/// It uses a dark theme style with specific border radiuses.
class EditRecordPopup extends StatefulWidget {
  final Record record;

  const EditRecordPopup({super.key, required this.record});

  @override
  State<EditRecordPopup> createState() => _EditRecordPopupState();
}

class _EditRecordPopupState extends State<EditRecordPopup> {
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late String _type;
  late int _selectedSourceId;
  late int _selectedCategoryId;

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
          backgroundColor: Colors.white,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.translate('edit_record_title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Type Toggle
                  _buildLabel(l10n.translate('type_label')),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildTypeOption(l10n.translate('income_label'), 'income', Colors.green),
                        _buildTypeOption(l10n.translate('spent_label'), 'expense', Colors.red),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount
                  _buildLabel(l10n.translate('income_label')), // Reuse label? Or add amount_label
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 15,
                      fontFamily: 'Poppins',
                    ),
                    decoration: _buildInputDecoration(
                      hint: '0.00',
                      error: _amountError != null ? l10n.translate(_amountError!) : null,
                    ),
                    onChanged: (_) {
                      if (_amountError != null) {
                        setState(() => _amountError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Money Source Dropdown
                  _buildLabel(l10n.translate('money_source_label')),
                  const SizedBox(height: 8),
                  _buildDropdown<int>(
                    value: _selectedSourceId,
                    items: moneySources.map((s) => DropdownMenuItem(
                      value: s.sourceId!,
                      child: Text(
                        s.sourceName,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontFamily: 'Poppins',
                          fontSize: 15,
                        ),
                      ),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedSourceId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Category Dropdown
                  _buildLabel(l10n.translate('category_label')),
                  const SizedBox(height: 8),
                  _buildDropdown<int>(
                    value: _selectedCategoryId,
                    items: categories
                        .where((c) => c.type == _type)
                        .map((c) => DropdownMenuItem(
                      value: c.categoryId!,
                      child: Text(
                        provider.getCategoryName(c.categoryId!),
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontFamily: 'Poppins',
                          fontSize: 15,
                        ),
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
                  const SizedBox(height: 20),

                  // Description
                  _buildLabel(l10n.translate('description_label')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 15,
                      fontFamily: 'Poppins',
                    ),
                    decoration: _buildInputDecoration(
                      hint: l10n.translate('description_hint'),
                      error: _descriptionError != null ? l10n.translate(_descriptionError!) : null,
                    ),
                    onChanged: (_) {
                      if (_descriptionError != null) {
                        setState(() => _descriptionError = null);
                      }
                    },
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l10n.translate('popup_cancel'),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleSave(provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            l10n.translate('save_button'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeOption(String label, String value, Color activeColor) {
    final isSelected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _type = value;
            // Optionally reset category if it doesn't match the new type
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontFamily: 'Poppins'),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, String? error}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontFamily: 'Poppins'),
      errorText: error,
      errorStyle: const TextStyle(fontFamily: 'Poppins'),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: Colors.white,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
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
      );

      Navigator.of(context).pop(updatedRecord);
    }
  }
}
