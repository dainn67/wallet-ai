import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/configs/app_theme.dart';

Future<void> showAddSubCategoryDialog({
  required BuildContext context,
  required Category parent,
}) async {
  final controller = TextEditingController();
  final l10n = context.read<LocaleProvider>();
  final recordProvider = context.read<RecordProvider>();

  showDialog(
    context: context,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.translate('add_sub_category'),
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.translate('category_name_hint'),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.translate('popup_cancel')),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      recordProvider.addCategory(Category(name: name, type: parent.type, parentId: parent.categoryId!));
                      Navigator.pop(context);
                    }
                  },
                  child: Text(l10n.translate('save_button')),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
