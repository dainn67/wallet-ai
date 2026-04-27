import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/components/popups/edit_record_popup.dart';
import 'package:wallet_ai/components/record_widget.dart';
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
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                _buildHeader(provider, total),
                Expanded(child: _buildBody(context, records, scrollController, provider)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(RecordProvider provider, double total) {
    final month = _monthLabel(provider.selectedDateRange);
    final isNegative = total < 0;
    final totalColor = isNegative ? Colors.red : Colors.green;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            category.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${CurrencyHelper.format(total.abs())}  •  $month',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: totalColor,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
    if (records.isEmpty) {
      return Center(
        child: Text(
          'No records in this category for ${_monthLabel(provider.selectedDateRange)}.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontFamily: 'Poppins',
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (subCategories.isEmpty) {
      // Flat list — sub-category tap or parent without subs
      return ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _buildSection(ctx, sections[i]),
    );
  }

  Widget _buildSection(BuildContext context, _Section section) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              section.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                fontFamily: 'Poppins',
              ),
            ),
          ),
          ...section.records.map((r) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _buildRecordRow(context, r),
              )),
          const SizedBox(height: 4),
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
