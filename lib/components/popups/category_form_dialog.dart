import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/configs/app_theme.dart';

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
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedType = widget.category?.type ?? 'expense';
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isEdit = widget.category != null;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      title: Text(
        isEdit ? l10n.translate('edit_category_title') : l10n.translate('add_category_title'),
        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                  style: textTheme.labelLarge?.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.translate('category_name_hint'),
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
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.translate('type_label'),
                  style: textTheme.labelLarge?.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _TypeButton(
                        label: l10n.translate('spent_label'),
                        isSelected: _selectedType == 'expense',
                        activeColor: colorScheme.error,
                        onTap: () => setState(() => _selectedType = 'expense'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _TypeButton(
                        label: l10n.translate('income_label'),
                        isSelected: _selectedType == 'income',
                        activeColor: AppColors.primary,
                        onTap: () => setState(() => _selectedType = 'income'),
                      ),
                    ),
                  ],
                ),
                if (isEdit) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _handleDelete(context),
                      icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                      label: Text(
                        l10n.translate('delete_button'),
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
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
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      actions: [
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
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final newCategory = Category(
                      categoryId: widget.category?.categoryId,
                      name: _nameController.text.trim(),
                      type: _selectedType,
                    );

                    if (isEdit) {
                      recordProvider.updateCategory(newCategory);
                    } else {
                      recordProvider.addCategory(newCategory);
                    }

                    Navigator.of(context).pop();
                  }
                },
                child: Text(l10n.translate('save_button')),
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
  final Color activeColor;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? activeColor : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
