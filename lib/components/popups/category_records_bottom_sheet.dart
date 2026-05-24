import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/components/popups/edit_record_popup.dart';
import 'package:wallet_ai/components/popups/transfer_info_popup.dart';
import 'package:wallet_ai/components/record_widget.dart';
import 'package:wallet_ai/configs/app_theme.dart';
import 'package:wallet_ai/helpers/currency_helper.dart';
import 'package:wallet_ai/models/category.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/providers/record_provider.dart';

/// Bottom sheet that shows all records belonging to a category (or union of
/// parent + sub-categories). Opens via [showModalBottomSheet] with
/// [isScrollControlled: true].
///
/// When [subCategories] is non-empty (parent tap), records are grouped into
/// bordered sections: parent-direct first, then one section per sub-category.
/// When [subCategories] is empty (sub tap), records are shown as a flat list.
class CategoryRecordsBottomSheet extends StatelessWidget {
  const CategoryRecordsBottomSheet({
    super.key,
    required this.category,
    required this.categoryIds,
    required this.subCategories,
  });

  final Category category;
  final List<int> categoryIds;
  final List<Category> subCategories;

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordProvider>(
      builder: (context, provider, _) {
        final records = provider.getRecordsForCategory(categoryIds, provider.selectedDateRange);
        final total = records.fold<double>(0, (sum, r) => sum + (r.type == 'expense' ? -r.amount : r.amount));

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollController) => Container(
            // BottomSheetThemeData from AppTheme.light() provides shape + color,
            // but DraggableScrollableSheet wraps with a Container so we apply here.
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
            ),
            child: Column(
              children: [
                _buildHeader(context, provider, total),
                Expanded(child: _buildBody(context, records, scrollController, provider)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, RecordProvider provider, double total) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final month = _monthLabel(provider.selectedDateRange);
    final isNegative = total < 0;

    // Semantic colors: expense red / income green from AppSemanticColors extension
    final sem = Theme.of(context).extension<AppSemanticColors>();
    final totalColor = isNegative
        ? (sem?.expenseRed ?? colorScheme.error)
        : (sem?.incomeGreen ?? colorScheme.primary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          Text(
            category.name,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${CurrencyHelper.format(total.abs())}  •  $month',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: totalColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: AppColors.outline),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<Record> records,
    ScrollController scrollController,
    RecordProvider provider,
  ) {
    final textTheme = Theme.of(context).textTheme;

    if (records.isEmpty) {
      return Center(
        child: Text(
          'No records in this category for ${_monthLabel(provider.selectedDateRange)}.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (subCategories.isEmpty) {
      // Flat list — sub-category tap or parent without subs
      return ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, i) => _buildRecordRow(ctx, records[i]),
      );
    }

    // Grouped list — parent tap
    final sections = <_Section>[];

    // Parent-direct group
    final parentDirect = records.where((r) => r.categoryId == category.categoryId).toList();
    if (parentDirect.isNotEmpty) {
      sections.add(_Section(title: category.name, records: parentDirect));
    }

    // One group per sub-category
    for (final sub in subCategories) {
      final subRecords = records.where((r) => r.categoryId == sub.categoryId).toList();
      if (subRecords.isNotEmpty) {
        sections.add(_Section(title: sub.name, records: subRecords));
      }
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (ctx, i) => _buildSection(ctx, sections[i]),
    );
  }

  Widget _buildSection(BuildContext context, _Section section) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm + AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              section.title,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ...section.records.map((r) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: _buildRecordRow(context, r),
              )),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }

  Widget _buildRecordRow(BuildContext context, Record record) {
    return RecordWidget(
      record: record,
      isEditable: true,
      onEdit: () => _showEditPopup(context, record),
    );
  }

  void _showEditPopup(BuildContext context, Record record) async {
    if (record.isTransfer) {
      await showDialog(
        context: context,
        builder: (_) => TransferInfoPopup(record: record),
      );
      return;
    }

    final updatedRecord = await showDialog<Record>(
      context: context,
      builder: (_) => EditRecordPopup(record: record),
    );

    if (updatedRecord != null && context.mounted) {
      await context.read<RecordProvider>().updateRecord(updatedRecord);
    }
  }

  String _monthLabel(DateTimeRange? range) {
    final date = range?.start ?? DateTime.now();
    return DateFormat('MMM yyyy').format(date);
  }
}

/// Internal data class for a grouped section.
class _Section {
  const _Section({required this.title, required this.records});
  final String title;
  final List<Record> records;
}
