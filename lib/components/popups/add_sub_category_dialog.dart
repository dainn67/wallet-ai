import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/helpers/emoji_helper.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

Future<void> showAddSubCategoryDialog({
  required BuildContext context,
  required Category parent,
}) async {
  final l10n = context.read<LocaleProvider>();
  final recordProvider = context.read<RecordProvider>();

  showDialog(
    context: context,
    builder: (context) => _AddSubCategoryDialog(
      parent: parent,
      l10n: l10n,
      recordProvider: recordProvider,
    ),
  );
}

class _AddSubCategoryDialog extends StatefulWidget {
  final Category parent;
  final LocaleProvider l10n;
  final RecordProvider recordProvider;

  const _AddSubCategoryDialog({
    required this.parent,
    required this.l10n,
    required this.recordProvider,
  });

  @override
  State<_AddSubCategoryDialog> createState() => _AddSubCategoryDialogState();
}

class _AddSubCategoryDialogState extends State<_AddSubCategoryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emojiController = TextEditingController(text: '🏷️');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.l10n.translate('add_sub_category'),
        style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.l10n.translate('category_name_hint'),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Emoji',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                AnimatedBuilder(
                  animation: _emojiController,
                  builder: (_, __) => Text(
                    _emojiController.text.isEmpty ? '🏷️' : _emojiController.text,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _emojiController,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Emoji',
                      counterText: '',
                      hintText: '🏷️',
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  widget.l10n.translate('popup_cancel'),
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isNotEmpty) {
                    final emoji = coerceEmoji(_emojiController.text);
                    widget.recordProvider.addCategory(Category(
                      name: name,
                      type: widget.parent.type,
                      parentId: widget.parent.categoryId!,
                      emoji: emoji,
                    ));
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  widget.l10n.translate('save_button'),
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
