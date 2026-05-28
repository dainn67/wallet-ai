import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/helpers/emoji_helper.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

import 'confirmation_dialog.dart';

class CategoryFormDialog extends StatefulWidget {
  final Category? category;

  const CategoryFormDialog({super.key, this.category});

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emojiController;
  late String _selectedType;
  String? _emojiError;

  bool get _isUncategorized => widget.category?.categoryId == 1;

  bool get _hasChanges {
    if (widget.category == null) return _nameController.text.trim().isNotEmpty;
    return _nameController.text.trim() != widget.category!.name ||
        coerceEmoji(_emojiController.text) != widget.category!.emoji ||
        _selectedType != widget.category!.type;
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty && _hasChanges;

  void _onChanged() => setState(() {});

  /// Allows only emoji codepoints, caps at 1 emoji (replacing previous), and
  /// sets [_emojiError] when the user types a non-emoji character.
  TextEditingValue _filterEmojiInput(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) {
      _setEmojiError(null);
      return newValue;
    }

    final hasInvalid = text.runes.any((cp) => !isEmojiCodepoint(cp) && !isEmojiModifier(cp));
    if (hasInvalid) {
      _setEmojiError(context.read<LocaleProvider>().translate('emoji_only_input_error'));
      return oldValue;
    }

    _setEmojiError(null);
    final groups = splitEmojiGroups(text);
    if (groups.isEmpty) return newValue;

    // Keep only the last emoji group so the previous emoji is replaced.
    final last = String.fromCharCodes(groups.last);
    if (last == text) return newValue;
    return TextEditingValue(
      text: last,
      selection: TextSelection.collapsed(offset: last.length),
    );
  }

  void _setEmojiError(String? message) {
    if (_emojiError == message) return;
    // Defer setState to avoid mutating state while the formatter pipeline runs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _emojiError = message);
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _emojiController = TextEditingController(text: widget.category?.emoji ?? '🏷️');
    _selectedType = widget.category?.type ?? 'expense';
    _nameController.addListener(_onChanged);
    _emojiController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onChanged);
    _emojiController.removeListener(_onChanged);
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete(BuildContext context) async {
    final recordProvider = context.read<RecordProvider>();
    final l10n = context.read<LocaleProvider>();
    final categoryId = widget.category!.categoryId!;

    final count = await recordProvider.getRecordCountByCategoryId(categoryId);

    if (!mounted) return;

    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmationDialog(
        title: l10n.translate('delete_category_confirm_title'),
        content: l10n.translate('delete_category_confirm_content').replaceFirst('{count}', count.toString()),
        confirmLabel: l10n.translate('delete_button'),
        cancelLabel: l10n.translate('popup_cancel'),
        isDestructive: true,
        onConfirm: () {
          recordProvider.deleteCategory(categoryId);
          Navigator.of(context).pop(); // Close CategoryFormDialog
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    final recordProvider = context.read<RecordProvider>();
    final isEdit = widget.category != null;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        isEdit ? l10n.translate('edit_category_title') : l10n.translate('add_category_title'),
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('category_name_label'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.translate('category_name_hint'),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.translate('name_required_error');
                  }

                  final exists = recordProvider.categories.any((c) =>
                    c.name.trim().toLowerCase() == value.trim().toLowerCase() &&
                    c.categoryId != widget.category?.categoryId
                  );

                  if (exists) {
                    return l10n.translate('category_already_exists');
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Emoji field
              const Text(
                'Emoji',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('emoji_field'),
                controller: _emojiController,
                enabled: !_isUncategorized,
                style: const TextStyle(fontSize: 22),
                inputFormatters: [
                  TextInputFormatter.withFunction(_filterEmojiInput),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  errorText: _emojiError,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('type_label'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: l10n.translate('spent_label'),
                      isSelected: _selectedType == 'expense',
                      color: Colors.red,
                      onTap: () => setState(() => _selectedType = 'expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeButton(
                      label: l10n.translate('income_label'),
                      isSelected: _selectedType == 'income',
                      color: Colors.green,
                      onTap: () => setState(() => _selectedType = 'income'),
                    ),
                  ),
                ],
              ),
              if (isEdit) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _handleDelete(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    label: Text(
                      l10n.translate('delete_button'),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.translate('popup_cancel'),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _canSave
                    ? () {
                        if (_formKey.currentState!.validate()) {
                          final newCategory = Category(
                            categoryId: widget.category?.categoryId,
                            name: _nameController.text.trim(),
                            type: _selectedType,
                            parentId: widget.category?.parentId ?? -1,
                            emoji: coerceEmoji(_emojiController.text),
                          );
                          if (isEdit) {
                            recordProvider.updateCategory(newCategory);
                          } else {
                            recordProvider.addCategory(newCategory);
                          }
                          Navigator.of(context).pop();
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.translate('save_button'),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? color : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}
