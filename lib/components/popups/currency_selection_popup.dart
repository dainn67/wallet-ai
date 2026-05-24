import 'package:flutter/material.dart';
import 'package:wallet_ai/configs/app_theme.dart';

Future<String?> showCurrencySelectionPopup({
  required BuildContext context,
  required String currentCurrency,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xxl,
            horizontal: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Currency',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildCurrencyOption(context, 'VND', 'Vietnamese Dong', currentCurrency, textTheme),
              _buildCurrencyOption(context, 'USD', 'US Dollar', currentCurrency, textTheme),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildCurrencyOption(
  BuildContext context,
  String code,
  String label,
  String current,
  TextTheme textTheme,
) {
  final isSelected = current == code;
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
    tileColor: isSelected ? AppColors.primaryContainer : null,
    leading: Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.payments_rounded,
        color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
        size: 20,
      ),
    ),
    title: Text(
      code,
      style: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: isSelected ? AppColors.primary : AppColors.onSurface,
      ),
    ),
    subtitle: Text(
      label,
      style: textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
    ),
    trailing: isSelected
        ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
        : null,
    onTap: () => Navigator.pop(context, code),
  );
}
