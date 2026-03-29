import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/components/components.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  void _showAddDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const CategoryFormDialog());
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
        final parentCategories = categories.where((c) => c.parentId == -1).toList();
        final selectedDate = provider.selectedDateRange?.start ?? DateTime.now();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.translate('drawer_categories'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.blue),
                    onPressed: () => _showAddDialog(context),
                  ),
                ],
              ),
            ),
            // Month Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF64748B)),
                      onPressed: () => context.read<RecordProvider>().navigateMonth(-1),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(selectedDate),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                      onPressed: () => context.read<RecordProvider>().navigateMonth(1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: parentCategories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(l10n.translate('no_categories'), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: parentCategories.length,
                      itemBuilder: (context, index) {
                        final category = parentCategories[index];
                        final subCategories = provider.getSubCategories(category.categoryId!);
                        final total = provider.getCategoryTotal(category.categoryId!);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.only(right: 12),
                              childrenPadding: EdgeInsets.zero,
                              collapsedBackgroundColor: Colors.transparent,
                              backgroundColor: Colors.transparent,
                              title: CategoryWidget(
                                category: category,
                                total: total,
                                typeLabel: category.type == 'income' ? l10n.translate('income_label') : l10n.translate('spent_label'),
                                defaultLabel: category.categoryId == 1 ? l10n.translate('category_default_label') : null,
                                onTap: null, // Let ExpansionTile handle tap
                                onEdit: category.categoryId == 1 ? null : () => _showEditDialog(context, category),
                                showChevron: false,
                                showDecoration: false,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              children: [
                                const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                                ...subCategories.map(
                                  (sub) => CategoryWidget(
                                    category: sub,
                                    total: provider.getCategoryTotal(sub.categoryId!),
                                    typeLabel: sub.type == 'income' ? l10n.translate('income_label') : l10n.translate('spent_label'),
                                    onTap: () => _showEditDialog(context, sub),
                                    showDecoration: false,
                                    padding: const EdgeInsets.only(left: 56, top: 8, bottom: 8, right: 16),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: InkWell(
                                    onTap: () => showAddSubCategoryDialog(context: context, parent: category),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.blue.withValues(alpha: 0.02),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.add, size: 14, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Text(
                                            l10n.translate('add_sub_category'),
                                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
