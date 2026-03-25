import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'confirmation_dialog.dart';

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
            Row(
              children: [
                const SizedBox(width: 48), // Spacer to balance the delete icon
                Expanded(
                  child: Text(
                    'Edit ${widget.source.sourceName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: _handleDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                  tooltip: 'Delete Source',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Update Amount',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontFamily: 'Poppins'),
                errorText: _amountError,
                errorStyle: const TextStyle(fontFamily: 'Poppins'),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Poppins'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Poppins'),
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

  void _handleSave() {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      setState(() => _amountError = 'Amount is required');
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null) {
      setState(() => _amountError = 'Invalid amount');
      return;
    }

    Navigator.of(context).pop(amount);
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmationDialog(
        title: 'Delete Source',
        content: 'Are you sure you want to delete \'${widget.source.sourceName}\'? This will also delete all transaction records associated with this source. This cannot be undone.',
        confirmLabel: 'Delete',
        cancelLabel: 'Cancel',
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
