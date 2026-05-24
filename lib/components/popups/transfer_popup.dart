import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

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

    final destinations = provider.moneySources
        .where((s) => s.sourceId != null && s.sourceId != widget.fromSource.sourceId)
        .toList();

    return Dialog(
      backgroundColor: Colors.white,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
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
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            _label(l10n.translate('transfer_from_label')),
            const SizedBox(height: 8),
            _readOnlyField(widget.fromSource.sourceName),
            const SizedBox(height: 16),

            _label(l10n.translate('transfer_to_label')),
            const SizedBox(height: 8),
            if (destinations.isEmpty)
              _readOnlyField(
                l10n.translate('transfer_no_other_source_error'),
                isError: true,
              )
            else
              _buildDestinationDropdown(destinations),
            if (_toError != null) ...[
              const SizedBox(height: 6),
              Text(
                l10n.translate(_toError!),
                style: const TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'Poppins'),
              ),
            ],
            const SizedBox(height: 16),

            _label(l10n.translate('transfer_amount_label')),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontFamily: 'Poppins'),
              decoration: _inputDecoration(
                hint: '0.00',
                error: _amountError != null ? l10n.translate(_amountError!) : null,
              ),
            ),
            const SizedBox(height: 16),

            _label(l10n.translate('transfer_note_label')),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontFamily: 'Poppins'),
              decoration: _inputDecoration(hint: l10n.translate('description_hint')),
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      l10n.translate('popup_cancel'),
                      style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Poppins'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_saving || destinations.isEmpty) ? null : () => _handleSave(provider, l10n),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            l10n.translate('transfer_button'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Poppins'),
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

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontFamily: 'Poppins'),
      );

  Widget _readOnlyField(String text, {bool isError = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isError ? Colors.red : const Color(0xFF1E293B),
            fontSize: 15,
            fontFamily: 'Poppins',
          ),
        ),
      );

  InputDecoration _inputDecoration({required String hint, String? error}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontFamily: 'Poppins'),
        errorText: error,
        errorStyle: const TextStyle(fontFamily: 'Poppins'),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Widget _buildDestinationDropdown(List<MoneySource> destinations) {
    // Reset selection if it no longer exists in the list.
    if (_toSourceId != null && !destinations.any((s) => s.sourceId == _toSourceId)) {
      _toSourceId = null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _toSourceId,
          isExpanded: true,
          hint: Text(
            context.read<LocaleProvider>().translate('transfer_select_to_hint'),
            style: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Poppins', fontSize: 15),
          ),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
          items: destinations
              .map(
                (s) => DropdownMenuItem<int>(
                  value: s.sourceId!,
                  child: Text(
                    s.sourceName,
                    style: const TextStyle(color: Color(0xFF1E293B), fontFamily: 'Poppins', fontSize: 15),
                  ),
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
