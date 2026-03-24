import 'package:flutter/material.dart';

Future<String?> showCurrencySelectionPopup({
  required BuildContext context,
  required String currentCurrency,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Currency',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 16),
              _buildCurrencyOption(context, 'VND', 'Vietnamese Dong', currentCurrency),
              _buildCurrencyOption(context, 'USD', 'US Dollar', currentCurrency),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildCurrencyOption(BuildContext context, String code, String label, String current) {
  final isSelected = current == code;
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.payments_rounded,
        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B),
        size: 20,
      ),
    ),
    title: Text(
      code,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
        fontFamily: 'Poppins',
      ),
    ),
    subtitle: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF64748B),
        fontFamily: 'Poppins',
      ),
    ),
    trailing: isSelected
        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1))
        : null,
    onTap: () => Navigator.pop(context, code),
  );
}
