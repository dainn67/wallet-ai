import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/providers.dart';
import '../../../components/components.dart';
import '../../../helpers/currency_helper.dart';
import '../../../models/models.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CategoryFormDialog(),
    );
  }

  void _showEditDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => CategoryFormDialog(category: category),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, Category category) async {
    final recordProvider = context.read<RecordProvider>();
    final l10n = context.read<LocaleProvider>();
    final count = await recordProvider.getRecordCountByCategoryId(category.categoryId!);
    
    if (!context.mounted) return;

    final content = l10n.translate('delete_category_confirm_content').replaceFirst('{count}', count.toString());

    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: l10n.translate('delete_category_confirm_title'),
        content: content,
        confirmLabel: l10n.translate('delete_button'),
        cancelLabel: l10n.translate('popup_cancel'),
        isDestructive: true,
        onConfirm: () {
          recordProvider.deleteCategory(category.categoryId!);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    return Consumer<RecordProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.categories.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = provider.categories;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  Text(
                    l10n.translate('drawer_categories'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.blue),
                    onPressed: () => _showAddDialog(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            l10n.translate('no_categories') ?? 'No categories yet',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: categories.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isUncategorized = category.categoryId == 1;
                        final total = provider.getCategoryTotal(category.categoryId!);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            category.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            category.type == 'income' 
                                ? l10n.translate('income_label') 
                                : l10n.translate('spent_label'),
                            style: TextStyle(
                              fontSize: 12,
                              color: category.type == 'income' ? Colors.green : Colors.red,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                CurrencyHelper.format(total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (!isUncategorized) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20, color: Color(0xFF64748B)),
                                  onPressed: () => _showEditDialog(context, category),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  onPressed: () => _showDeleteConfirmation(context, category),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ] else ...[
                                const SizedBox(width: 16),
                                const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCBD5E1)),
                              ],
                            ],
                          ),
                          onTap: () {
                            // Will be implemented in task 012
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
