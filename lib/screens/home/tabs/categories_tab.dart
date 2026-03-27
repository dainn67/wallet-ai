import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/providers.dart';
import '../../../components/components.dart';
import '../../../models/models.dart';

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

  void _showAddSubCategoryDialog(BuildContext context, Category parent) {
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
                                padding: const EdgeInsets.all(16),
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
                                    padding: const EdgeInsets.only(left: 56, top: 12, bottom: 12, right: 16),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 56, bottom: 16, top: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      onTap: () => _showAddSubCategoryDialog(context, category),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.blue.withValues(alpha: 0.03),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.add, size: 14, color: Colors.blue),
                                            const SizedBox(width: 6),
                                            Text(
                                              l10n.translate('add_sub_category'),
                                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 12),
                                            ),
                                          ],
                                        ),
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
