import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/components/components.dart';
import 'package:wallet_ai/configs/app_theme.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  final Map<int, ExpansibleController> _controllers = {};

  void _showAddDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const CategoryFormDialog());
  }

  void _showEditDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => CategoryFormDialog(category: category),
    );
  }

  void _openCategoryPopup(BuildContext context, Category category, {required bool isParent}) {
    final provider = context.read<RecordProvider>();
    final subCats = isParent ? provider.getSubCategories(category.categoryId!) : <Category>[];
    final ids = [category.categoryId!, ...subCats.map((s) => s.categoryId!)];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryRecordsBottomSheet(
        category: category,
        categoryIds: ids,
        subCategories: subCats,
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
        final selectedDate = provider.selectedDateRange?.start ?? DateTime.now();

        for (final cat in parentCategories) {
          _controllers.putIfAbsent(cat.categoryId!, () => ExpansibleController());
        }

        return Column(
          children: [
            // Header row: title label + Add Category button
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.translate('drawer_categories'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    // NOTE: using add_category_title key — no standalone add_category key exists.
                    // T9 cleanup can add a dedicated key if needed.
                    label: Text(l10n.translate('add_category_title')),
                    onPressed: () => _showAddDialog(context),
                  ),
                ],
              ),
            ),

            // Date-period pill navigator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: () => context.read<RecordProvider>().navigateMonth(-1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      DateFormat('MMMM yyyy').format(selectedDate),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: () => context.read<RecordProvider>().navigateMonth(1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Expanded(
              child: parentCategories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, size: 48, color: AppColors.onSurfaceVariant),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            l10n.translate('no_categories'),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      itemCount: parentCategories.length,
                      itemBuilder: (context, index) {
                        final category = parentCategories[index];
                        final subCategories = provider.getSubCategories(category.categoryId!);
                        final total = provider.getCategoryTotal(category.categoryId!);
                        final controller = _controllers[category.categoryId!]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          // Card container with themed surface + shadow
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.outline),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              controller: controller,
                              tilePadding: const EdgeInsets.only(right: AppSpacing.md),
                              childrenPadding: EdgeInsets.zero,
                              collapsedBackgroundColor: Colors.transparent,
                              backgroundColor: Colors.transparent,
                              trailing: IconButton(
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.onSurfaceVariant),
                                onPressed: () => controller.isExpanded ? controller.collapse() : controller.expand(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              title: CategoryWidget(
                                category: category,
                                total: total,
                                typeLabel: category.type == 'income' ? l10n.translate('income_label') : l10n.translate('spent_label'),
                                defaultLabel: category.categoryId == 1 ? l10n.translate('category_default_label') : null,
                                onTap: () => _openCategoryPopup(context, category, isParent: true),
                                onEdit: category.categoryId == 1 ? null : () => _showEditDialog(context, category),
                                showChevron: false,
                                showDecoration: false,
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                              ),
                              children: [
                                Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg, color: AppColors.outlineVariant),
                                ...subCategories.map(
                                  (sub) => SubCategoryWidget(
                                    category: sub,
                                    total: provider.getCategoryTotal(sub.categoryId!),
                                    typeLabel: sub.type == 'income' ? l10n.translate('income_label') : l10n.translate('spent_label'),
                                    onTap: () => _openCategoryPopup(context, sub, isParent: false),
                                    onEdit: () => _showEditDialog(context, sub),
                                  ),
                                ),
                                // Add sub-category button
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                                  child: InkWell(
                                    onTap: () => showAddSubCategoryDialog(context: context, parent: category),
                                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + AppSpacing.xs),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                                        color: AppColors.primary.withValues(alpha: 0.02),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.add, size: 14, color: AppColors.primary),
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            l10n.translate('add_sub_category'),
                                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
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
