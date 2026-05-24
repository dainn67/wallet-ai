import 'package:flutter/material.dart';

import 'package:wallet_ai/configs/app_theme.dart';
import 'package:wallet_ai/helpers/currency_helper.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/storage_service.dart';
import 'package:wallet_ai/components/icon_square.dart';

/// Parent category row — used as the title inside an [ExpansionTile] in
/// [CategoriesTab]. The outer [Card] and [ExpansionTile] wrapper live in
/// [CategoriesTab]; this widget provides only the leading + name + trailing
/// area so it can be cleanly composed.
///
/// InkWell absorption: the edit [IconButton] has a non-null [onPressed],
/// so it absorbs the pointer event before the parent [ExpansionTile.onExpansionChanged]
/// fires. [onTap] is forwarded to [ListTile.onTap] for drill-down popups.
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

  /// Returns an icon based on category type.
  IconData _iconForCategory() {
    switch (category.type) {
      case 'income':
        return Icons.arrow_downward_rounded;
      case 'expense':
        return Icons.arrow_upward_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isUncategorized = category.categoryId == 1;
    final displayName = isUncategorized && defaultLabel != null ? '${category.name} ($defaultLabel)' : category.name;
    final currency = StorageService().getString(StorageService.keyCurrency) ?? 'USD';

    return ListTile(
      contentPadding: padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      // NTH-2: per-category tint deferred — all parents use AppColors.primary in v1
      leading: IconSquare(
        icon: _iconForCategory(),
        tint: AppColors.primary,
      ),
      title: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        typeLabel,
        style: textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyHelper.format(total),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                currency,
                style: textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          if (onEdit != null) ...[
            const SizedBox(width: AppSpacing.xs),
            // InkWell absorption: onPressed non-null absorbs tap here,
            // preventing ExpansionTile from firing expand/collapse.
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: AppColors.onSurfaceVariant,
            ),
          ],
          if (showChevron) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.onSurfaceVariant),
          ],
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// Sub-category row — rendered as children of the [ExpansionTile] in
/// [CategoriesTab]. Has a 3dp left accent border in [AppColors.primary].
/// No [IconSquare] — per FR-7 sub-row spec.
class SubCategoryWidget extends StatelessWidget {
  final Category category;
  final double total;
  final String typeLabel;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const SubCategoryWidget({
    super.key,
    required this.category,
    required this.total,
    required this.typeLabel,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currency = StorageService().getString(StorageService.keyCurrency) ?? 'USD';

    return Container(
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.tile),
          bottomRight: Radius.circular(AppRadius.tile),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        title: Text(
          category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          typeLabel,
          style: textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyHelper.format(total),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  currency,
                  style: textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            if (onEdit != null) ...[
              const SizedBox(width: AppSpacing.xs),
              // InkWell absorption: onPressed non-null absorbs sub-row tap here.
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
