import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

/// A popup dialog for adding a new [MoneySource].
///
/// This dialog captures the source name and an initial balance.
/// It uses a dark theme style with specific border radiuses.
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
              l10n.translate('add_source_title'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildLabel(l10n.translate('source_name_label')),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontFamily: 'Poppins'),
              decoration: _buildInputDecoration(
                hint: l10n.translate('source_name_hint'),
                error: _nameError != null ? l10n.translate(_nameError!) : null,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            _buildLabel(l10n.translate('initial_amount_label')),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontFamily: 'Poppins'),
              decoration: _buildInputDecoration(
                hint: '0.00',
                error: _amountError != null ? l10n.translate(_amountError!) : null,
              ),
            ),
            const SizedBox(height: 32),
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
                      style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Poppins'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleSave(l10n),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.translate('save_button'),
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
