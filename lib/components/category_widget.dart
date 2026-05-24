import 'package:flutter/material.dart';

import 'package:wallet_ai/helpers/currency_helper.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/storage_service.dart';

class CategoryWidget extends StatelessWidget {
  final Category category;
  final double total;
  final String typeLabel;
  final String? defaultLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final bool showChevron;
  final bool showDecoration;
  final EdgeInsets? padding;

  const CategoryWidget({
    super.key,
    required this.category,
    required this.total,
    required this.typeLabel,
    this.defaultLabel,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.showChevron = true,
    this.showDecoration = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = category.type == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final backgroundColor = color.withValues(alpha: 0.1);
    final isUncategorized = category.categoryId == 1;

    Widget content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: showDecoration
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
            )
          : null,
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
            child: Icon(isExpense ? Icons.arrow_outward_rounded : Icons.call_received_rounded, color: color, size: 16),
          ),
          const SizedBox(width: 12),

          // Name and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        isUncategorized && defaultLabel != null ? '${category.name} ($defaultLabel)' : category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ),
                    if (onEdit != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.edit_rounded, size: 10, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(typeLabel, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),

          // Amount and Chevron
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyHelper.format(total),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 1),
              Text(
                StorageService().getString(StorageService.keyCurrency) ?? 'USD',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          if (showChevron) ...[const SizedBox(width: 8), const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCBD5E1))],
        ],
      ),
    );

    return InkWell(onTap: onTap, onLongPress: onLongPress, borderRadius: BorderRadius.circular(16), child: content);
  }
}
