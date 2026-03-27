import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/providers.dart';
import '../../../components/components.dart';
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final total = provider.getCategoryTotal(category.categoryId!);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CategoryWidget(
                            category: category,
                            total: total,
                            typeLabel: category.type == 'income' 
                                ? l10n.translate('income_label') 
                                : l10n.translate('spent_label'),
                            defaultLabel: category.categoryId == 1 ? l10n.translate('category_default_label') : null,
                            onTap: category.categoryId == 1 ? null : () => _showEditDialog(context, category),
                          ),
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
