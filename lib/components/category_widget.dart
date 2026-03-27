import 'package:flutter/material.dart';
import '../models/models.dart';
import '../helpers/currency_helper.dart';

class CategoryWidget extends StatelessWidget {
  final Category category;
  final double total;
  final String typeLabel;
  final String? defaultLabel;
  final VoidCallback? onTap;

  const CategoryWidget({
    super.key,
    required this.category,
    required this.total,
    required this.typeLabel,
    this.defaultLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = category.type == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final backgroundColor = color.withValues(alpha: 0.1);
    final isUncategorized = category.categoryId == 1;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
              child: Icon(
                isExpense ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),

            // Name and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUncategorized && defaultLabel != null 
                        ? '${category.name} ($defaultLabel)' 
                        : category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    typeLabel,
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ],
              ),
            ),

            // Amount and Chevron
            const SizedBox(width: 8),
            Text(
              CurrencyHelper.format(total),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}
