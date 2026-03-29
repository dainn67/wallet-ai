import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

Future<void> showAddSubCategoryDialog({
  required BuildContext context,
  required Category parent,
}) async {
  final controller = TextEditingController();
  final l10n = context.read<LocaleProvider>();
  final recordProvider = context.read<RecordProvider>();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        l10n.translate('add_sub_category'),
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        textAlign: TextAlign.center,
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.translate('category_name_hint'),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.translate('popup_cancel'),
                  style: const TextStyle(fontFamily: 'Poppins', color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    recordProvider.addCategory(Category(name: name, type: parent.type, parentId: parent.categoryId!));
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  l10n.translate('save_button'),
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
